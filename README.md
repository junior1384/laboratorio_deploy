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
- acesso SSH ao servidor
- usuário com sudo
- Git instalado
- conexão com a internet
- GitHub Actions Runner instalado no servidor
- Runner conectado ao repositório `laboratorio_deploy`
- secret `SUDO_PASSWORD` configurado no GitHub

### Como o GitHub acessa o servidor

O projeto utiliza um GitHub Actions Runner instalado no próprio servidor.

O Runner mantém uma conexão com o GitHub e recebe os jobs para execução.

O fluxo é:

GitHub
↓
laboratorio_deploy
↓
GitHub Actions
↓
Self-hosted Runner
↓
Servidor Ubuntu

Os workflows utilizam:

`runs-on: self-hosted`

Dessa forma, o GitHub envia o job para o Runner disponível no servidor.

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

## Verificação do servidor

Antes de executar o Provision, execute o workflow:

`Check Server`

Esse workflow executa automaticamente:

```bash
chmod +x scripts/check-server.sh
./scripts/check-server.sh
```
