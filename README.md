# Laboratório Deploy

Sistema genérico de CI/CD para aplicações hospedadas em GitHub.

## Antes de utilizar

O servidor Ubuntu precisa atender alguns pré-requisitos.

### Pré-requisitos

- Ubuntu instalado
- acesso SSH ao servidor
- usuário com sudo
- Git instalado
- conexão com a internet
- GitHub Actions Runner instalado
- Runner conectado ao repositório
- secret `SUDO_PASSWORD` configurado no GitHub

### O que o sistema configura automaticamente

Após os pré-requisitos serem atendidos, o projeto configura:

- diretórios de deploy
- ambientes TEST e PROD
- serviços systemd
- permissões
- regras sudo
- execução das aplicações
- deploy
- health check
- rollback

## Verificação

Antes de executar o Provision, execute:

./scripts/check-server.sh

O script verifica todos os pré-requisitos e informa exatamente
o que está faltando.