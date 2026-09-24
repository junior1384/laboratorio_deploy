#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="${1:-}"
REF="${2:-}"
ENVIRONMENT="${3:-}"

DOTNET_DIR="/home/juniorwinkler/.dotnet"
DOTNET_BIN="$DOTNET_DIR/dotnet"
DOTNET_INSTALL_SCRIPT="/tmp/dotnet-install.sh"

echo "======================================"
echo " DEPLOY"
echo "======================================"

if [[ -z "$REPOSITORY" || -z "$REF" || -z "$ENVIRONMENT" ]]; then
    echo "Uso:"
    echo "./scripts/deploy.sh <repository> <ref> <environment>"
    exit 1
fi

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
        exit 1
        ;;
esac

echo "Repositório : $REPOSITORY"
echo "Ref         : $REF"
echo "Ambiente    : $ENVIRONMENT"
echo "Diretório   : $APP_DIR"
echo "Serviço     : $SERVICE"
echo "Porta       : $PORT"

WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}

trap cleanup EXIT

echo
echo "======================================"
echo " BAIXANDO APLICAÇÃO"
echo "======================================"

REPOSITORY_URL="https://github.com/${REPOSITORY}.git"

git clone \
    --depth 1 \
    --branch "$REF" \
    "$REPOSITORY_URL" \
    "$WORK_DIR/app"

RELEASE_ID="$(git -C "$WORK_DIR/app" rev-parse HEAD)"

echo "Repositório baixado."
echo "Commit: $RELEASE_ID"

echo
echo "======================================"
echo " DETECTANDO TECNOLOGIA"
echo "======================================"

TECHNOLOGY=""
PROJECT_FILE=""

if find "$WORK_DIR/app" -maxdepth 3 -name "*.csproj" -print -quit | grep -q .; then
    TECHNOLOGY="dotnet"
    PROJECT_FILE="$(find "$WORK_DIR/app" -maxdepth 3 -name "*.csproj" -print -quit)"

elif [[ -f "$WORK_DIR/app/package.json" ]]; then
    TECHNOLOGY="node"

elif [[ -f "$WORK_DIR/app/requirements.txt" || -f "$WORK_DIR/app/pyproject.toml" ]]; then
    TECHNOLOGY="python"

else
    echo "ERRO: tecnologia não identificada."
    exit 1
fi

echo "Tecnologia detectada: $TECHNOLOGY"

echo
echo "======================================"
echo " BUILD"
echo "======================================"

if [[ "$TECHNOLOGY" == "dotnet" ]]; then

    echo "Projeto: $PROJECT_FILE"

    if [[ ! -f "$PROJECT_FILE" ]]; then
        echo "ERRO: projeto .NET não encontrado."
        exit 1
    fi

    echo
    echo "======================================"
    echo " DETECTANDO TARGET FRAMEWORK"
    echo "======================================"

    TARGET_FRAMEWORK="$(
        grep -oPm1 '(?<=<TargetFramework>)[^<]+' "$PROJECT_FILE" || true
    )"

    if [[ -z "$TARGET_FRAMEWORK" ]]; then
        TARGET_FRAMEWORK="$(
            grep -oPm1 '(?<=<TargetFrameworks>)[^<]+' "$PROJECT_FILE" \
            | cut -d';' -f1 || true
        )"
    fi

    if [[ -z "$TARGET_FRAMEWORK" ]]; then
        echo "ERRO: não foi possível identificar o TargetFramework."
        exit 1
    fi

    echo "Target Framework: $TARGET_FRAMEWORK"

    if [[ ! "$TARGET_FRAMEWORK" =~ ^net[0-9]+\.[0-9]+ ]]; then
        echo "ERRO: TargetFramework não suportado automaticamente:"
        echo "$TARGET_FRAMEWORK"
        exit 1
    fi

    DOTNET_CHANNEL="${BASH_REMATCH[0]#net}"

    echo "Versão .NET necessária: $DOTNET_CHANNEL"

    echo
    echo "======================================"
    echo " GARANTINDO SDK .NET"
    echo "======================================"

    mkdir -p "$DOTNET_DIR"

    if [[ ! -x "$DOTNET_BIN" ]]; then
        echo ".NET não encontrado."
        echo "Instalando SDK necessário..."
        DOTNET_INSTALLED=0

    elif "$DOTNET_BIN" --list-sdks | grep -q "^${DOTNET_CHANNEL}\."; then
        echo "SDK .NET $DOTNET_CHANNEL já está instalado."
        DOTNET_INSTALLED=1

    else
        echo "SDK .NET $DOTNET_CHANNEL não encontrado."
        echo "Instalando SDK necessário..."
        DOTNET_INSTALLED=0
    fi

    if [[ "$DOTNET_INSTALLED" -eq 0 ]]; then

        if [[ ! -f "$DOTNET_INSTALL_SCRIPT" ]]; then
            echo "Baixando dotnet-install.sh..."

            curl \
                --fail \
                --silent \
                --show-error \
                --location \
                https://dot.net/v1/dotnet-install.sh \
                --output "$DOTNET_INSTALL_SCRIPT"

            chmod +x "$DOTNET_INSTALL_SCRIPT"
        fi

        "$DOTNET_INSTALL_SCRIPT" \
            --channel "$DOTNET_CHANNEL" \
            --install-dir "$DOTNET_DIR" \
            --no-path
    fi

    if [[ ! -x "$DOTNET_BIN" ]]; then
        echo "ERRO: .NET não está disponível em:"
        echo "$DOTNET_BIN"
        exit 1
    fi

    echo
    echo "SDKs disponíveis:"
    "$DOTNET_BIN" --list-sdks

    echo
    echo "Verificando SDK necessário..."

    if ! "$DOTNET_BIN" --list-sdks | grep -q "^${DOTNET_CHANNEL}\."; then
        echo "ERRO: SDK .NET $DOTNET_CHANNEL não foi instalado corretamente."
        exit 1
    fi

    echo "SDK .NET $DOTNET_CHANNEL disponível."

    echo
    echo "======================================"
    echo " PUBLICANDO APLICAÇÃO"
    echo "======================================"

    PROJECT_NAME="$(basename "$PROJECT_FILE" .csproj)"
    PUBLISH_DIR="$WORK_DIR/publish"

    echo "Projeto : $PROJECT_FILE"
    echo "Saída   : $PUBLISH_DIR"
    echo "Runtime : $DOTNET_BIN"

    "$DOTNET_BIN" publish \
        "$PROJECT_FILE" \
        --configuration Release \
        --output "$PUBLISH_DIR"

    MAIN_DLL="$PUBLISH_DIR/$PROJECT_NAME.dll"

    if [[ ! -f "$MAIN_DLL" ]]; then
        echo "ERRO: DLL principal não encontrada:"
        echo "$MAIN_DLL"
        exit 1
    fi

else

    echo "ERRO: build ainda não configurado para:"
    echo "$TECHNOLOGY"
    exit 1

fi

echo
echo "Build concluído."

RELEASE_DIR="$APP_DIR/releases/$RELEASE_ID"

echo
echo "======================================"
echo " CRIANDO RELEASE"
echo "======================================"

if [[ -d "$RELEASE_DIR" ]]; then
    echo "Release já existe. Reutilizando."
else
    mkdir -p "$RELEASE_DIR"

    cp -a "$PUBLISH_DIR"/. "$RELEASE_DIR"/

    ln -s "$PROJECT_NAME.dll" "$RELEASE_DIR/app.dll"

    echo "Release criada."
fi

PREVIOUS_RELEASE=""

if [[ -L "$APP_DIR/current" ]]; then
    PREVIOUS_RELEASE="$(readlink -f "$APP_DIR/current")"
fi

echo "Release anterior: ${PREVIOUS_RELEASE:-nenhuma}"

# ============================================================
# Função de rollback
# ============================================================

rollback() {

    echo
    echo "======================================"
    echo " ROLLBACK"
    echo "======================================"

    if [[ -z "$PREVIOUS_RELEASE" ]]; then
        echo "Nenhuma release anterior disponível."
        return 1
    fi

    echo "Release anterior:"
    echo "$PREVIOUS_RELEASE"

    if [[ ! -d "$PREVIOUS_RELEASE" ]]; then
        echo "ERRO: release anterior não existe."
        return 1
    fi

    if [[ ! -f "$PREVIOUS_RELEASE/app.dll" ]]; then
        echo "ERRO: release anterior não possui app.dll."
        echo "Rollback cancelado para evitar ativar uma release incompatível."
        return 1
    fi

    echo "Release anterior validada."

    ln -s "$PREVIOUS_RELEASE" "$APP_DIR/current.rollback"

    mv -Tf "$APP_DIR/current.rollback" "$APP_DIR/current"

    echo "Current restaurado:"
    readlink -f "$APP_DIR/current"

    sudo -n systemctl restart "$SERVICE"

    echo "Serviço reiniciado após rollback."

    return 0
}

echo
echo "======================================"
echo " VALIDANDO RELEASE"
echo "======================================"

if [[ ! -f "$RELEASE_DIR/app.dll" ]]; then
    echo "ERRO: release criada não possui app.dll."
    exit 1
fi

echo "Release válida."

echo
echo "======================================"
echo " ATUALIZANDO CURRENT"
echo "======================================"

ln -s "$RELEASE_DIR" "$APP_DIR/current.new"

mv -Tf "$APP_DIR/current.new" "$APP_DIR/current"

echo "Current:"
readlink -f "$APP_DIR/current"

echo
echo "======================================"
echo " REINICIANDO SERVIÇO"
echo "======================================"

sudo -n systemctl restart "$SERVICE"

echo
echo "======================================"
echo " VALIDANDO SERVIÇO"
echo "======================================"

sleep 2

if ! sudo -n systemctl is-active --quiet "$SERVICE"; then

    echo "ERRO: serviço não ficou ativo."

    sudo -n systemctl status "$SERVICE" --no-pager || true

    rollback || true

    exit 1
fi

echo "Serviço ativo."

echo
echo "======================================"
echo " HEALTH CHECK"
echo "======================================"

HEALTH_URL="http://127.0.0.1:${PORT}/health"

echo "URL: $HEALTH_URL"

HEALTH_OK=0

for attempt in {1..5}; do

    echo "Tentativa $attempt/5..."

    if curl \
        --fail \
        --silent \
        --show-error \
        "$HEALTH_URL"; then

        HEALTH_OK=1
        break
    fi

    sleep 2
done

if [[ "$HEALTH_OK" -ne 1 ]]; then

    echo
    echo "ERRO: health check falhou."

    sudo -n systemctl status "$SERVICE" --no-pager || true

    rollback || true

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