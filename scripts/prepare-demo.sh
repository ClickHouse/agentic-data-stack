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
            ((idx++))
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
            up)     ((active--)); if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
            down)   ((active++)); if [ $active -ge ${#options[@]} ]; then active=0; fi;;
            ctrlc)  cursor_blink_on; printf "\n"; exit 130;;
        esac
    done

    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    eval $retval='("${selected[@]}")'
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
    echo ""
    echo "✅ Demo environment is ready!"
    exit 0
fi

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

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^${env_key}=.*|${env_key}=${api_key}|" "$ENV_FILE"
    else
        sed -i "s|^${env_key}=.*|${env_key}=${api_key}|" "$ENV_FILE"
    fi

    echo "  ✓ ${provider} key saved"
done

echo ""
echo "✅ Demo environment is ready!"
echo ""
echo "  Summary:"
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
echo ""
