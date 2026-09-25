#!/usr/bin/env bash

set -u

ERRORS=0

echo "======================================"
echo " SERVER CHECK"
echo "======================================"
echo

check_ok() {
    echo "[OK] $1"
}

check_error() {
    echo "[ERRO] $1"
    ERRORS=$((ERRORS + 1))
}

echo "======================================"
echo " 1. SISTEMA OPERACIONAL"
echo "======================================"

if [[ -f /etc/os-release ]]; then
    . /etc/os-release

    if [[ "${ID:-}" == "ubuntu" ]]; then
        check_ok "Ubuntu instalado: ${PRETTY_NAME:-Ubuntu}"
    else
        check_error "O sistema operacional não é Ubuntu."
    fi
else
    check_error "Não foi possível identificar o sistema operacional."
fi

echo

echo "======================================"
echo " 2. USUÁRIO"
echo "======================================"

CURRENT_USER="$(whoami)"

if [[ -n "$CURRENT_USER" ]]; then
    check_ok "Usuário atual: $CURRENT_USER"
else
    check_error "Não foi possível identificar o usuário atual."
fi

echo

echo "======================================"
echo " 3. SUDO"
echo "======================================"

if command -v sudo >/dev/null 2>&1; then
    if sudo -n true >/dev/null 2>&1; then
        check_ok "sudo disponível para o usuário $CURRENT_USER"
    else
        check_error "O usuário $CURRENT_USER não possui sudo sem interação."
    fi
else
    check_error "sudo não está instalado."
fi

echo

echo "======================================"
echo " 4. GIT"
echo "======================================"

if command -v git >/dev/null 2>&1; then
    GIT_VERSION="$(git --version)"
    check_ok "Git instalado: $GIT_VERSION"
else
    check_error "Git não está instalado."
fi

echo

echo "======================================"
echo " 5. CONEXÃO COM A INTERNET"
echo "======================================"

if command -v curl >/dev/null 2>&1; then
    if curl --fail --silent --show-error --connect-timeout 5 \
        https://github.com >/dev/null 2>&1; then
        check_ok "Conexão com a internet disponível."
    else
        check_error "Não foi possível acessar https://github.com."
    fi
else
    check_error "curl não está instalado. Não foi possível testar a conexão."
fi

echo

echo "======================================"
echo " 6. GITHUB ACTIONS RUNNER"
echo "======================================"

RUNNER_DIR="$HOME/actions-runner"

if [[ -d "$RUNNER_DIR" ]]; then
    check_ok "Diretório do GitHub Actions Runner encontrado: $RUNNER_DIR"
else
    check_error "GitHub Actions Runner não encontrado em: $RUNNER_DIR"
fi

echo

echo "======================================"
echo " 7. STATUS DO RUNNER"
echo "======================================"

RUNNER_SERVICE="actions.runner.junior1384-laboratorio_deploy.laboratorio-deploy-runner.service"

if systemctl list-unit-files | grep -q "^${RUNNER_SERVICE}"; then

    if systemctl is-active --quiet "$RUNNER_SERVICE"; then
        check_ok "GitHub Actions Runner está ativo."
    else
        check_error "GitHub Actions Runner está instalado, mas não está ativo."
    fi

else
    check_error "Serviço do GitHub Actions Runner não encontrado."
fi

echo

echo "======================================"
echo " RESULTADO"
echo "======================================"

if [[ "$ERRORS" -eq 0 ]]; then
    echo
    echo "SERVIDOR PRONTO"
    echo
    echo "Todos os pré-requisitos verificados foram atendidos."
    echo
    exit 0
else
    echo
    echo "SERVIDOR NÃO ESTÁ PRONTO"
    echo
    echo "Foram encontrados $ERRORS problema(s)."
    echo "Corrija os itens acima antes de continuar."
    echo
    exit 1
fi