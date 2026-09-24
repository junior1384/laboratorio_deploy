#!/usr/bin/env bash

set -euo pipefail

echo "======================================"
echo " Provisionamento do servidor"
echo "======================================"

echo
echo "Hostname:"
hostname

echo
echo "Usuário:"
whoami

echo
echo ".NET:"
dotnet --version

echo
echo "Provisionamento iniciado..."