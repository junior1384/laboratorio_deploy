#!/usr/bin/env bash

set -euo pipefail

REPO="https://github.com/junior1384/laboratorio_deploy"
RUNNER_DIR="$HOME/actions-runner"
RUNNER_NAME="laboratorio-deploy-runner"

if [[ -z "${RUNNER_TOKEN:-}" ]]; then
    echo "ERRO: RUNNER_TOKEN não foi informado."
    echo
    echo "Execute antes:"
    echo "export RUNNER_TOKEN='SEU_TOKEN'"
    exit 1
fi

echo "======================================"
echo " Bootstrap GitHub Actions Runner"
echo "======================================"

echo
echo "Usuário:"
whoami

echo
echo "Arquitetura:"
uname -m

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "ERRO: este bootstrap suporta apenas Linux x64."
    exit 1
fi

echo
echo "Verificando Ubuntu..."

if [[ ! -f /etc/os-release ]]; then
    echo "ERRO: não foi possível identificar o sistema operacional."
    exit 1
fi

. /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "ERRO: o sistema operacional não é Ubuntu."
    exit 1
fi

echo "Ubuntu detectado: ${PRETTY_NAME:-Ubuntu}"

echo
echo "Verificando Runner existente..."

if [[ -f "$RUNNER_DIR/config.sh" ]]; then
    echo "ERRO: já existe um Runner configurado em:"
    echo "$RUNNER_DIR"
    echo
    echo "Nenhuma alteração foi realizada."
    exit 1
fi

echo
echo "Validando sudo..."

sudo -v

echo
echo "Criando diretório do Runner..."

mkdir -p "$RUNNER_DIR"

cd "$RUNNER_DIR"

echo
echo "Descobrindo versão atual do GitHub Actions Runner..."

RUNNER_URL="$(
    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/actions/runner/releases/latest" |
        grep '"browser_download_url":' |
        grep 'actions-runner-linux-x64-' |
        head -n 1 |
        cut -d '"' -f 4
)"

if [[ -z "$RUNNER_URL" ]]; then
    echo "ERRO: não foi possível descobrir a versão do Runner."
    exit 1
fi

RUNNER_ARCHIVE="$(basename "$RUNNER_URL")"

echo
echo "Runner encontrado:"
echo "$RUNNER_ARCHIVE"

echo
echo "Baixando Runner..."

curl -fL \
    -o "$RUNNER_ARCHIVE" \
    "$RUNNER_URL"

echo
echo "Extraindo Runner..."

tar xzf "$RUNNER_ARCHIVE"

rm -f "$RUNNER_ARCHIVE"

echo
echo "Instalando dependências do Runner..."

sudo ./bin/installdependencies.sh

echo
echo "Configurando Runner..."

./config.sh --unattended --url "$REPO" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --work "_work"

echo
echo "Instalando Runner como serviço..."

sudo ./svc.sh install "$USER"

echo
echo "Iniciando Runner..."

sudo ./svc.sh start

unset RUNNER_TOKEN

echo
echo "======================================"
echo " Runner configurado"
echo "======================================"

echo
echo "Status do Runner:"

sudo ./svc.sh status

echo
echo "Bootstrap concluído."