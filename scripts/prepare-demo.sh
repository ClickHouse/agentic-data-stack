#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "No .env file found. Generating one..."
    bash "$SCRIPT_DIR/generate-env.sh"
    echo ""
fi

# ── Interactive multi-select ──────────────────────────────────────────
# Adapted from https://serverfault.com/a/949806

PROVIDERS=("OpenAI" "Anthropic" "Google")
ENV_KEYS=("OPENAI_API_KEY" "ANTHROPIC_API_KEY" "GOOGLE_KEY")

multiselect() {
    local retval=$1
    local -a options=("${!2}")
    local -a selected=()
    local active=0

    ESC=$(printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }

    print_active()     { printf "  $ESC[36m❯ $ESC[7m %s %s $ESC[27m$ESC[0m$ESC[K" "$1" "$2"; }
    print_inactive()   { printf "    %s %s$ESC[K" "$1" "$2"; }

    key_input() {
        local key
        IFS= read -rsn1 key 2>/dev/null >&2

        if [[ $key = "" ]];      then echo enter; fi
        if [[ $key = $'\x20' ]]; then echo space; fi
        if [[ $key = $'\x03' ]]; then echo ctrlc; fi
        if [[ $key = $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key = [A ]]; then echo up; fi
            if [[ $key = [B ]]; then echo down; fi
        fi
    }

    for ((i = 0; i < ${#options[@]}; i++)); do
        selected+=("false")
        printf "\n"
    done

    local lastrow=$(get_cursor_row)
    local startrow=$(($lastrow - ${#options[@]}))

    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    while true; do
        local idx=0
        for option in "${options[@]}"; do
            local prefix="[ ]"
            if [[ ${selected[idx]} == "true" ]]; then
                prefix="[✔]"
            fi

            cursor_to $(($startrow + $idx))
            if [ $idx -eq $active ]; then
                print_active "$prefix" "$option"
            else
                print_inactive "$prefix" "$option"
            fi
            idx=$((idx + 1))
        done

        case $(key_input) in
            space)
                if [[ ${selected[$active]} == "true" ]]; then
                    selected[$active]="false"
                else
                    selected[$active]="true"
                fi
                ;;
            enter)  break;;
            up)     
                active=$((active - 1)); 
                if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
            down)   
                active=$((active + 1));  
                if [ $active -ge ${#options[@]} ]; then active=0; fi;;
            ctrlc)  cursor_blink_on; printf "\n"; exit 130;;
        esac
    done

    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    eval $retval='("${selected[@]}")'
}

# Upsert KEY=VALUE in $ENV_FILE — replace if present, append otherwise.
set_env_var() {
    local key="$1"
    local value="$2"
    local escaped_value
    escaped_value=$(printf '%s' "$value" | sed -e 's/[\\&|]/\\&/g')
    if grep -q "^${key}=" "$ENV_FILE"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${key}=.*|${key}=${escaped_value}|" "$ENV_FILE"
        else
            sed -i "s|^${key}=.*|${key}=${escaped_value}|" "$ENV_FILE"
        fi
    else
        printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    fi
}

echo "=== API Key Configuration ==="
echo ""
echo "  Select which providers to configure with API keys."
echo "  Unchecked providers environment variables not modified."
echo ""
echo "  ↑/↓ to navigate · Space to toggle · Enter to confirm"

multiselect RESULT PROVIDERS[@]

SELECTED=()
for i in "${!RESULT[@]}"; do
    if [[ ${RESULT[$i]} == "true" ]]; then
        SELECTED+=("$i")
    fi
done

if [ ${#SELECTED[@]} -eq 0 ]; then
    echo "  No providers selected — API key environment variables not modified."
else
    echo ""
    for i in "${SELECTED[@]}"; do
        provider="${PROVIDERS[$i]}"
        env_key="${ENV_KEYS[$i]}"

        while true; do
            read -s -p "  Enter $provider API key: " api_key
            echo ""
            if [ -n "$api_key" ]; then
                break
            fi
            echo "  Key cannot be empty. Try again or Ctrl+C to abort."
        done

        set_env_var "$env_key" "$api_key"

        echo "  ✓ ${provider} key saved"
    done
fi

# Ensure the LibreChat-side Langfuse keys exist in .env. Older .env files
# (generated before LANGFUSE_PUBLIC_KEY / SECRET_KEY / BASE_URL were split out)
# only have the LANGFUSE_INIT_PROJECT_* values; default the new keys to the
# local Langfuse stack so the "local" choice keeps working untouched.
if ! grep -q "^LANGFUSE_BASE_URL=" "$ENV_FILE"; then
    set_env_var "LANGFUSE_BASE_URL" "http://langfuse-web:3000"
fi
if ! grep -q "^LANGFUSE_PUBLIC_KEY=" "$ENV_FILE"; then
    init_pub=$(grep -E "^LANGFUSE_INIT_PROJECT_PUBLIC_KEY=" "$ENV_FILE" | head -n1 | cut -d= -f2-)
    set_env_var "LANGFUSE_PUBLIC_KEY" "${init_pub}"
fi
if ! grep -q "^LANGFUSE_SECRET_KEY=" "$ENV_FILE"; then
    init_sec=$(grep -E "^LANGFUSE_INIT_PROJECT_SECRET_KEY=" "$ENV_FILE" | head -n1 | cut -d= -f2-)
    set_env_var "LANGFUSE_SECRET_KEY" "${init_sec}"
fi

echo ""
echo "=== Langfuse Instrumentation ==="
echo ""
echo "  LibreChat sends LLM traces to Langfuse for observability."
echo "  By default, traces stay local (the Langfuse container in this stack)."
echo "  You can instead send them to a Langfuse Cloud (or other remote) project."
echo ""

LANGFUSE_TARGET="local"
while true; do
    read -p "  Use Langfuse Cloud / a remote project? [y/N] " langfuse_cloud_choice
    case "${langfuse_cloud_choice}" in
        [yY]|[yY][eE][sS])
            LANGFUSE_TARGET="cloud"
            break
            ;;
        ""|[nN]|[nN][oO])
            LANGFUSE_TARGET="local"
            break
            ;;
        *)
            echo "  Please answer y or n."
            ;;
    esac
done

if [ "$LANGFUSE_TARGET" = "cloud" ]; then
    echo ""
    echo "  Enter the connection details for your remote Langfuse project."
    echo "  (Project Settings -> API Keys in the Langfuse UI.)"
    echo ""

    while true; do
        read -p "  Langfuse base URL [https://cloud.langfuse.com]: " langfuse_base_url
        langfuse_base_url="${langfuse_base_url:-https://cloud.langfuse.com}"
        if [[ "$langfuse_base_url" =~ ^https?:// ]]; then
            break
        fi
        echo "  Base URL must start with http:// or https://. Try again."
    done

    while true; do
        read -p "  Langfuse public key (pk-lf-...): " langfuse_public_key
        if [ -n "$langfuse_public_key" ]; then
            break
        fi
        echo "  Public key cannot be empty. Try again or Ctrl+C to abort."
    done

    while true; do
        read -s -p "  Langfuse secret key (sk-lf-...): " langfuse_secret_key
        echo ""
        if [ -n "$langfuse_secret_key" ]; then
            break
        fi
        echo "  Secret key cannot be empty. Try again or Ctrl+C to abort."
    done

    set_env_var "LANGFUSE_BASE_URL" "$langfuse_base_url"
    set_env_var "LANGFUSE_PUBLIC_KEY" "$langfuse_public_key"
    set_env_var "LANGFUSE_SECRET_KEY" "$langfuse_secret_key"

    echo "  ✓ LibreChat will send traces to ${langfuse_base_url}"
else
    echo "  ✓ LibreChat will send traces to the local Langfuse stack."
fi

echo ""
echo "✅ Demo environment is ready!"
echo ""
echo "  Provider summary:"
if [ ${#SELECTED[@]} -eq 0 ]; then
    for i in "${!PROVIDERS[@]}"; do
        echo "    - ${PROVIDERS[$i]}  (user_provided)"
    done
else
    for i in "${!PROVIDERS[@]}"; do
        found=false
        for s in "${SELECTED[@]}"; do
            [ "$s" = "$i" ] && found=true && break
        done
        if $found; then
            echo "    ✔ ${PROVIDERS[$i]}  (configured)"
        else
            echo "    - ${PROVIDERS[$i]}  (user_provided)"
        fi
    done
fi
echo ""
echo "  Langfuse target: ${LANGFUSE_TARGET}"
echo ""
echo "  Run 'docker compose up -d' to get started."
echo ""
