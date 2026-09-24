#!/usr/bin/env bash

set -euo pipefail

echo "======================================"
echo " Provisionamento do servidor"
echo "======================================"

APP_ROOT="/var/www"

TEST_DIR="$APP_ROOT/deploy-lab-test"
PROD_DIR="$APP_ROOT/deploy-lab-prod"

echo
echo "Criando estrutura de diretórios..."

mkdir -p "$TEST_DIR/releases"
mkdir -p "$PROD_DIR/releases"

echo
echo "Garantindo permissões..."

chown -R juniorwinkler:juniorwinkler "$TEST_DIR"
chown -R juniorwinkler:juniorwinkler "$PROD_DIR"

echo
echo "======================================"
echo " Estrutura criada"
echo "======================================"

echo
echo "HOMOLOG:"
ls -la "$TEST_DIR"

echo
echo "PROD:"
ls -la "$PROD_DIR"

echo
echo "Provisionamento concluído."