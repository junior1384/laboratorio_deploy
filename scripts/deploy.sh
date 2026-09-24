#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="${1:-}"
REF="${2:-}"
ENVIRONMENT="${3:-}"

echo "======================================"
echo " DEPLOY"
echo "======================================"

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

case "$ENVIRONMENT" in
    test|prod)
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

# ======================================
# Preparar diretório temporário
# ======================================

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

echo
echo "======================================"
echo " CONTEÚDO DA APLICAÇÃO"
echo "======================================"

find "$WORK_DIR/app" \
    -maxdepth 2 \
    -type f \
    -not -path "*/.git/*" \
    | sort

echo
echo "======================================"
echo " DETECTANDO TECNOLOGIA"
echo "======================================"

if find "$WORK_DIR/app" -maxdepth 2 -name "*.csproj" -print -quit | grep -q .; then
    TECHNOLOGY="dotnet"
    PROJECT_FILE="$(find "$WORK_DIR/app" -maxdepth 2 -name "*.csproj" -print -quit)"

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

if [[ "$TECHNOLOGY" == "dotnet" ]]; then
    echo "Projeto .NET: $(basename "$PROJECT_FILE")"
fi

echo
echo "======================================"
echo " BUILD"
echo "======================================"

if [[ "$TECHNOLOGY" == "dotnet" ]]; then

    PUBLISH_DIR="$WORK_DIR/publish"

    echo
    echo "Projeto : $PROJECT_FILE"
    echo "Saída   : $PUBLISH_DIR"

    dotnet publish \
        "$PROJECT_FILE" \
        --configuration Release \
        --output "$PUBLISH_DIR"

    echo
    echo "Build concluído."

    echo
    echo "======================================"
    echo " ARTEFATO GERADO"
    echo "======================================"

    find "$PUBLISH_DIR" \
        -maxdepth 2 \
        -type f \
        | sort

else
    echo "ERRO: tecnologia ainda não possui build configurado: $TECHNOLOGY"
    exit 1
fi