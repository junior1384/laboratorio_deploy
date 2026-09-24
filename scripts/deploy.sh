#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="${1:-}"
REF="${2:-}"
ENVIRONMENT="${3:-}"

DOTNET_BIN="/home/juniorwinkler/.dotnet/dotnet"

echo "======================================"
echo " DEPLOY"
echo "======================================"

# ======================================
# Validar parâmetros
# ======================================

if [[ -z "$REPOSITORY" ]]; then
    echo "ERRO: repositório não informado."
    echo "Uso: ./scripts/deploy.sh <repository> <ref> <environment>"
    exit 1
fi

if [[ -z "$REF" ]]; then
    echo "ERRO: ref não informado."
    echo "Uso: ./scripts/deploy.sh <repository> <ref> <environment>"
    exit 1
fi

if [[ -z "$ENVIRONMENT" ]]; then
    echo "ERRO: ambiente não informado."
    echo "Uso: ./scripts/deploy.sh <repository> <ref> <environment>"
    exit 1
fi

# ======================================
# Configuração do ambiente
# ======================================

case "$ENVIRONMENT" in
    test)
        APP_DIR="/var/www/deploy-lab-test"
        SERVICE="deploy-lab-test.service"
        PORT="5001"
        ;;
    prod)
        APP_DIR="/var/www/deploy-lab-prod"
        SERVICE="deploy-lab-prod.service"
        PORT="5002"
        ;;
    *)
        echo "ERRO: ambiente inválido: $ENVIRONMENT"
        echo "Ambientes permitidos: test ou prod"
        exit 1
        ;;
esac

echo
echo "Repositório : $REPOSITORY"
echo "Ref         : $REF"
echo "Ambiente    : $ENVIRONMENT"
echo "Diretório   : $APP_DIR"
echo "Serviço     : $SERVICE"
echo "Porta       : $PORT"

# ======================================
# Preparar diretório temporário
# ======================================

WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}

trap cleanup EXIT

# ======================================
# Baixar aplicação
# ======================================

echo
echo "======================================"
echo " BAIXANDO APLICAÇÃO"
echo "======================================"

REPOSITORY_URL="https://github.com/${REPOSITORY}.git"

echo
echo "URL : $REPOSITORY_URL"
echo "REF : $REF"

git clone \
    --depth 1 \
    --branch "$REF" \
    "$REPOSITORY_URL" \
    "$WORK_DIR/app"

echo
echo "Repositório baixado."

# ======================================
# Identificar commit
# ======================================

RELEASE_ID="$(git -C "$WORK_DIR/app" rev-parse HEAD)"

echo
echo "======================================"
echo " RELEASE"
echo "======================================"

echo "Commit: $RELEASE_ID"

# ======================================
# Detectar tecnologia
# ======================================

echo
echo "======================================"
echo " DETECTANDO TECNOLOGIA"
echo "======================================"

if find "$WORK_DIR/app" -maxdepth 2 -name "*.csproj" -print -quit | grep -q .; then

    TECHNOLOGY="dotnet"

    PROJECT_FILE="$(find "$WORK_DIR/app" \
        -maxdepth 2 \
        -name "*.csproj" \
        -print -quit)"

elif [[ -f "$WORK_DIR/app/package.json" ]]; then

    TECHNOLOGY="node"

elif [[ -f "$WORK_DIR/app/requirements.txt" ]]; then

    TECHNOLOGY="python"

else

    echo "ERRO: não foi possível detectar a tecnologia da aplicação."
    exit 1

fi

echo
echo "Tecnologia detectada: $TECHNOLOGY"

# ======================================
# Build
# ======================================

echo
echo "======================================"
echo " BUILD"
echo "======================================"

if [[ "$TECHNOLOGY" == "dotnet" ]]; then

    PROJECT_NAME="$(basename "$PROJECT_FILE" .csproj)"
    PUBLISH_DIR="$WORK_DIR/publish"

    echo
    echo "Projeto : $PROJECT_FILE"
    echo "Saída   : $PUBLISH_DIR"
    echo "Runtime : $DOTNET_BIN"

    if [[ ! -x "$DOTNET_BIN" ]]; then
        echo "ERRO: .NET não encontrado em:"
        echo "$DOTNET_BIN"
        exit 1
    fi

    "$DOTNET_BIN" publish \
        "$PROJECT_FILE" \
        --configuration Release \
        --output "$PUBLISH_DIR"

    MAIN_DLL="$PUBLISH_DIR/$PROJECT_NAME.dll"

    if [[ ! -f "$MAIN_DLL" ]]; then
        echo
        echo "ERRO: DLL principal não encontrada:"
        echo "$MAIN_DLL"
        exit 1
    fi

else

    echo "ERRO: tecnologia ainda não possui build configurado: $TECHNOLOGY"
    exit 1

fi

echo
echo "Build concluído."

# ======================================
# Criar release
# ======================================

RELEASE_DIR="$APP_DIR/releases/$RELEASE_ID"

echo
echo "======================================"
echo " CRIANDO RELEASE"
echo "======================================"

echo "Release: $RELEASE_DIR"

if [[ -d "$RELEASE_DIR" ]]; then
    echo "Release já existe. Reutilizando."
else
    mkdir -p "$RELEASE_DIR"

    cp -a "$PUBLISH_DIR"/. "$RELEASE_DIR"/

    ln -s "$PROJECT_NAME.dll" "$RELEASE_DIR/app.dll"

    echo "Release criada."
fi

# ======================================
# Guardar release atual
# ======================================

PREVIOUS_RELEASE=""

if [[ -L "$APP_DIR/current" ]]; then
    PREVIOUS_RELEASE="$(readlink -f "$APP_DIR/current")"
fi

echo
echo "Release anterior:"
if [[ -n "$PREVIOUS_RELEASE" ]]; then
    echo "$PREVIOUS_RELEASE"
else
    echo "nenhuma"
fi

# ======================================
# Atualizar current
# ======================================

echo
echo "======================================"
echo " ATUALIZANDO CURRENT"
echo "======================================"

ln -s "$RELEASE_DIR" "$APP_DIR/current.new"

mv -Tf "$APP_DIR/current.new" "$APP_DIR/current"

echo "Current:"
readlink -f "$APP_DIR/current"

# ======================================
# Reiniciar serviço
# ======================================

echo
echo "======================================"
echo " REINICIANDO SERVIÇO"
echo "======================================"

sudo -n systemctl restart "$SERVICE"

echo "Serviço reiniciado."

# ======================================
# Validar serviço
# ======================================

echo
echo "======================================"
echo " VALIDANDO SERVIÇO"
echo "======================================"

if ! sudo -n systemctl is-active --quiet "$SERVICE"; then

    echo "ERRO: serviço não ficou ativo."

    sudo -n systemctl status "$SERVICE" --no-pager || true

    if [[ -n "$PREVIOUS_RELEASE" ]]; then

        echo
        echo "Restaurando release anterior..."

        ln -s "$PREVIOUS_RELEASE" "$APP_DIR/current.rollback"

        mv -Tf "$APP_DIR/current.rollback" "$APP_DIR/current"

        sudo -n systemctl restart "$SERVICE"

    fi

    exit 1
fi

echo "Serviço ativo."

# ======================================
# Health check
# ======================================

echo
echo "======================================"
echo " HEALTH CHECK"
echo "======================================"

HEALTH_URL="http://127.0.0.1:${PORT}/health"

echo "URL: $HEALTH_URL"

if ! curl \
    --fail \
    --silent \
    --show-error \
    "$HEALTH_URL"; then

    echo
    echo "ERRO: health check falhou."

    if [[ -n "$PREVIOUS_RELEASE" ]]; then

        echo
        echo "Restaurando release anterior..."

        ln -s "$PREVIOUS_RELEASE" "$APP_DIR/current.rollback"

        mv -Tf "$APP_DIR/current.rollback" "$APP_DIR/current"

        sudo -n systemctl restart "$SERVICE"

    fi

    exit 1
fi

echo
echo
echo "======================================"
echo " DEPLOY OK"
echo "======================================"

echo "Aplicação : $REPOSITORY"
echo "Ref       : $REF"
echo "Commit    : $RELEASE_ID"
echo "Ambiente  : $ENVIRONMENT"
echo "Release   : $RELEASE_DIR"
echo "Serviço   : $SERVICE"
echo "Health    : $HEALTH_URL"

echo
echo "Deploy concluído com sucesso."