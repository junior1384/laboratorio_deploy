# Laboratório Deploy

Sistema genérico de CI/CD para aplicações hospedadas no GitHub.

O projeto centraliza o provisionamento do servidor, deploy, health check e
rollback das aplicações, sem necessidade de criar workflows de deploy nos
repositórios das aplicações.

## Antes de utilizar

O servidor Ubuntu precisa atender alguns pré-requisitos para que o
GitHub Actions consiga executar os workflows.

### Pré-requisitos

- Ubuntu instalado
  Windows PowerShell.
  Execute:
  wsl --install -d Ubuntu
- usuário com sudo
  Ubuntu
  sudo -v
- Git instalado
  sudo apt update
  sudo apt install -y git
- conexão com a internet
  curl -I https://github.com
- GitHub Actions Runner instalado no servidor
  cd ~
  git clone https://github.com/junior1384/laboratorio_deploy.git
  cd ~/laboratorio_deploy
  — preparar o token do GitHub Runner
  Agora vamos para o GitHub, não no Ubuntu.
  No repositório:
  junior1384/laboratorio_deploy
  vá em:
  Settings → Actions → Runners → New self-hosted runner
  Selecione:
  Linux
  x64
  O GitHub vai mostrar um comando de configuração com um token temporário.
  Ubuntu
  export RUNNER_TOKEN='COLE_O_TOKEN_AQUI'
- Runner conectado ao repositório `laboratorio_deploy`  
   executar o bootstrap do Runner
  chmod +x scripts/bootstrap-runner.sh
  ./scripts/bootstrap-runner.sh
- secret `SUDO_PASSWORD` configurado no GitHub

Antes de executar o Provision, execute o workflow:

`Check Server` https://github.com/junior1384/laboratorio_deploy/wiki/CHECKSERVER

`Provision Server` https://github.com/junior1384/laboratorio_deploy/wiki/PROVISIONSERVER
