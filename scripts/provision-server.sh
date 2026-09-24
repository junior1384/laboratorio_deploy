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
echo " Verificando sudo atual"
echo "======================================"

if sudo -n true 2>/dev/null; then
    echo "SUDO_SEM_SENHA=SIM"
else
    echo "SUDO_SEM_SENHA=NAO"
fi

echo
echo "======================================"
echo " Configurando permissões sudo"
echo "======================================"

SUDOERS_FILE="/etc/sudoers.d/laboratorio-deploy"

sudo tee "$SUDOERS_FILE" > /dev/null <<EOF
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl daemon-reload
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl start deploy-lab-test.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl stop deploy-lab-test.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl restart deploy-lab-test.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl status deploy-lab-test.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl enable deploy-lab-test.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl disable deploy-lab-test.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl start deploy-lab-prod.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl stop deploy-lab-prod.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl restart deploy-lab-prod.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl status deploy-lab-prod.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl enable deploy-lab-prod.service
juniorwinkler ALL=(root) NOPASSWD: /usr/bin/systemctl disable deploy-lab-prod.service
EOF

sudo chmod 440 "$SUDOERS_FILE"

echo
echo "Validando configuração do sudo..."

sudo visudo -cf "$SUDOERS_FILE"

echo
echo "======================================"
echo " Configurando serviços systemd"
echo "======================================"

echo
echo "Criando serviço HOMOLOG..."

sudo tee /etc/systemd/system/deploy-lab-test.service > /dev/null <<EOF
[Unit]
Description=Deploy Lab API - TEST
After=network.target

[Service]
WorkingDirectory=/var/www/deploy-lab-test/current
ExecStart=/home/juniorwinkler/.dotnet/dotnet /var/www/deploy-lab-test/current/app.dll
Environment=ASPNETCORE_URLS=http://0.0.0.0:5001
Environment=ASPNETCORE_ENVIRONMENT=Test
Restart=always
RestartSec=5
User=juniorwinkler

[Install]
WantedBy=multi-user.target
EOF

echo
echo "Criando serviço PROD..."

sudo tee /etc/systemd/system/deploy-lab-prod.service > /dev/null <<EOF
[Unit]
Description=Deploy Lab API - PROD
After=network.target

[Service]
WorkingDirectory=/var/www/deploy-lab-prod/current
ExecStart=/home/juniorwinkler/.dotnet/dotnet /var/www/deploy-lab-prod/current/app.dll
Environment=ASPNETCORE_URLS=http://0.0.0.0:5002
Environment=ASPNETCORE_ENVIRONMENT=Production
Restart=always
RestartSec=5
User=juniorwinkler

[Install]
WantedBy=multi-user.target
EOF

echo
echo "Recarregando systemd..."

sudo systemctl daemon-reload

echo
echo "======================================"
echo " Habilitando serviços"
echo "======================================"

sudo systemctl enable deploy-lab-test.service
sudo systemctl enable deploy-lab-prod.service

echo
echo "======================================"
echo " Configurando runner como serviço"
echo "======================================"

RUNNER_DIR="/home/juniorwinkler/actions-runner"
RUNNER_SVC="$RUNNER_DIR/svc.sh"

if [[ ! -x "$RUNNER_SVC" ]]; then
    echo "ERRO: runner não encontrado em:"
    echo "$RUNNER_DIR"
    exit 1
fi

echo
echo "Verificando serviço do runner..."

RUNNER_SERVICE="$(
    find /etc/systemd/system \
        -maxdepth 1 \
        -type f \
        -name 'actions.runner.*.service' \
        -printf '%f\n' \
        | head -n 1
)"

if [[ -z "$RUNNER_SERVICE" ]]; then
    echo "Serviço do runner não está instalado."
    echo "Instalando serviço do runner..."

    "$RUNNER_SVC" install juniorwinkler

    echo
    echo "Recarregando systemd..."

    systemctl daemon-reload

    RUNNER_SERVICE="$(
        find /etc/systemd/system \
            -maxdepth 1 \
            -type f \
            -name 'actions.runner.*.service' \
            -printf '%f\n' \
            | head -n 1
    )"
else
    echo "Serviço do runner já está instalado:"
    echo "$RUNNER_SERVICE"
fi

if [[ -z "$RUNNER_SERVICE" ]]; then
    echo "ERRO: serviço do runner não foi criado."
    exit 1
fi

echo
echo "Serviço do runner:"
echo "$RUNNER_SERVICE"

echo
echo "Habilitando serviço do runner para iniciar com o sistema..."

systemctl enable "$RUNNER_SERVICE"

echo
echo "Status do serviço do runner:"

systemctl status "$RUNNER_SERVICE" --no-pager || true

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
echo "======================================"
echo " Serviços atuais"
echo "======================================"

echo
echo "HOMOLOG:"
systemctl status deploy-lab-test.service --no-pager || true

echo
echo "PROD:"
systemctl status deploy-lab-prod.service --no-pager || true

echo
echo "======================================"
echo " Configuração dos serviços"
echo "======================================"

echo
echo "HOMOLOG:"
systemctl cat deploy-lab-test.service || true

echo
echo "PROD:"
systemctl cat deploy-lab-prod.service || true

echo
echo "======================================"
echo " Testando sudo sem senha"
echo "======================================"

sudo -n systemctl status deploy-lab-test.service --no-pager || true

echo
echo "Provisionamento concluído."