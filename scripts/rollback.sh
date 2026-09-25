#!/usr/bin/env bash

set -euo pipefail

ENVIRONMENT="${1:-}"

if [[ -z "$ENVIRONMENT" ]]; then
    echo "ERRO: informe o ambiente."
    echo "Uso: ./scripts/rollback.sh test|prod"
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
        echo "Use: test ou prod"
        exit 1
        ;;
esac

RELEASES_DIR="$APP_DIR/releases"
CURRENT_LINK="$APP_DIR/current"

echo "======================================"
echo " ROLLBACK"
echo "======================================"
echo
echo "Ambiente : $ENVIRONMENT"
echo "Diretório: $APP_DIR"
echo "Serviço  : $SERVICE"
echo

if [[ ! -d "$RELEASES_DIR" ]]; then
    echo "ERRO: diretório de releases não encontrado:"
    echo "$RELEASES_DIR"
    exit 1
fi

CURRENT_RELEASE="$(readlink -f "$CURRENT_LINK")"

if [[ -z "$CURRENT_RELEASE" ]]; then
    echo "ERRO: current não aponta para uma release."
    exit 1
fi

echo "Release atual:"
echo "$CURRENT_RELEASE"


PREVIOUS_LINK="$CURRENT_RELEASE/previous"

if [[ ! -L "$PREVIOUS_LINK" ]]; then
    echo
    echo "ERRO: a release atual não possui referência para a release anterior."
    echo "$PREVIOUS_LINK"
    exit 1
fi

PREVIOUS_RELEASE="$(readlink -f "$PREVIOUS_LINK")"

if [[ -z "$PREVIOUS_RELEASE" ]]; then
    echo
    echo "ERRO: não foi possível resolver a release anterior."
    exit 1
fi

if [[ ! -f "$PREVIOUS_RELEASE/app.dll" ]]; then
    echo
    echo "ERRO: release anterior não possui app.dll:"
    echo "$PREVIOUS_RELEASE"
    exit 1
fi

echo
echo "Release anterior:"
echo "$PREVIOUS_RELEASE"

if [[ ! -f "$PREVIOUS_RELEASE/app.dll" ]]; then
    echo
    echo "ERRO: release anterior não possui app.dll:"
    echo "$PREVIOUS_RELEASE"
    exit 1
fi

echo
echo "Alterando current..."

ln -sfn "$PREVIOUS_RELEASE" "$CURRENT_LINK"

echo
echo "Reiniciando serviço..."

sudo -n systemctl restart "$SERVICE"

echo
echo "Validando serviço..."

if ! sudo -n systemctl is-active --quiet "$SERVICE"; then
    echo "ERRO: serviço não ficou ativo."
    sudo -n systemctl status "$SERVICE" --no-pager || true
    exit 1
fi

echo "Serviço ativo."

echo
echo "Health check:"
echo "http://127.0.0.1:$PORT/health"

echo "Aguardando aplicação ficar disponível..."

HEALTH_URL="http://127.0.0.1:$PORT/health"

for ATTEMPT in {1..30}; do
    if curl --fail --silent --show-error "$HEALTH_URL"; then
        echo
        echo "Health check OK."
        break
    fi

    if [[ "$ATTEMPT" -eq 30 ]]; then
        echo
        echo "ERRO: health check falhou após 30 segundos."
        sudo -n systemctl status "$SERVICE" --no-pager || true
        exit 1
    fi

    echo "Tentativa $ATTEMPT/30 falhou. Aguardando 1 segundo..."
    sleep 1
done

echo
echo
echo "======================================"
echo " ROLLBACK OK"
echo "======================================"
echo
echo "Ambiente : $ENVIRONMENT"
echo "Release  : $PREVIOUS_RELEASE"