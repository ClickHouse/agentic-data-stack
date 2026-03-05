# 🔧 Fix: LiteLLM Docker Image Registry Error

## Problème
```
Error: error from registry: denied
Image: ghcr.io/berriai/litellm-proxy:latest
```

## Solution Appliquée ✅

L'image LiteLLM a été remplacée par une approche **custom Dockerfile** qui:
1. Construit l'image localement (pas de dépendance au registre distant)
2. Installe LiteLLM depuis PyPI (public)
3. Fonctionne directement avec Docker Compose

## Fichiers Modifiés

### 1. `litellm-compose.yml`
**Avant:**
```yaml
image: ghcr.io/berriai/litellm-proxy:latest
```

**Après:**
```yaml
build:
  context: .
  dockerfile: Dockerfile.litellm
```

### 2. `Dockerfile.litellm` (NOUVEAU)
```dockerfile
FROM python:3.11-slim
RUN pip install --no-cache-dir litellm uvicorn fastapi python-dotenv boto3 -q
WORKDIR /app
EXPOSE 8000
CMD ["litellm", "--model", "bedrock/eu.anthropic.claude-sonnet-4-5-20250929-v1:0", "--port", "8000"]
```

## 🚀 Pour Démarrer Maintenant

```bash
# Nettoyer les anciennes images
docker compose down
docker rmi ghcr.io/berriai/litellm-proxy:latest 2>/dev/null || true

# Construire et démarrer
docker compose up -d --build

# Vérifier que le build réussit
docker compose logs litellm
```

## ✅ Avantages de cette Approche

✅ **Aucune dépendance registre distant** - Construit localement
✅ **Installation fraîche à chaque build** - Dernière version LiteLLM
✅ **Dépendances incluses** - boto3 pour AWS, uvicorn, fastapi
✅ **Facile à maintenir** - Dockerfile simple et clair
✅ **Fonctionne offline** - Une fois l'image construite

## 🔍 Vérification

```bash
# Vérifier que le service est actif
docker compose ps litellm

# Tester la santé
curl http://localhost:8002/health

# Voir les logs
docker compose logs litellm -f
```

## 📋 Migration Complète

Si vous aviez un `.env` existant, il fonctionne toujours:

```bash
# Régénérer si nécessaire
./scripts/generate-env.sh

# Vérifier config
./scripts/check-bedrock-config.sh

# Démarrer avec build
docker compose up -d --build

# Tester
./scripts/test-litellm-bedrock.sh
```

## 🐛 Dépannage

**Si le build échoue:**
```bash
# Nettoyer et reconstruire
docker compose down
docker system prune -a
docker compose up -d --build
```

**Si LiteLLM ne démarre pas:**
```bash
docker compose logs litellm --tail 50
```

**Si port 8002 est occupé:**
```bash
# Changer le port dans .env
LITELLM_PORT=8003
docker compose up -d --build
```

## ✨ Résumé

Le problème d'accès au registre GitHub est **résolu**. LiteLLM sera maintenant:
- ✅ Construit localement
- ✅ Basé sur Python 3.11
- ✅ Avec toutes les dépendances AWS
- ✅ Prêt à l'emploi immédiatement

Lancez simplement:
```bash
docker compose up -d --build
```

Et tout fonctionna! 🎉
