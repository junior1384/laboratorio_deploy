## Check Server

O workflow **Check Server** verifica se o servidor está preparado para executar o restante do processo de provisionamento e deploy.

Ele **não instala nem configura nada no servidor**. Sua função é apenas validar os pré-requisitos necessários.

### O que o Check Server verifica

O script `scripts/check-server.sh` verifica:

1. **Sistema operacional**
   - Confirma se o servidor está executando Ubuntu.

2. **Usuário atual**
   - Identifica o usuário utilizado pelo GitHub Actions Runner.

3. **Sudo**
   - Verifica se o usuário atual possui acesso ao `sudo`.
   - Neste momento, o sudo **não precisa ser configurado como NOPASSWD**.
   - A configuração das permissões específicas sem senha será feita posteriormente pelo **Provision Server**.

4. **Git**
   - Confirma que o Git está instalado.

5. **Conexão com a internet**
   - Testa se o servidor consegue acessar o GitHub.

6. **GitHub Actions Runner**
   - Verifica se o diretório do Runner existe.

7. **Status do Runner**
   - Confirma se o serviço do GitHub Actions Runner está instalado e ativo.

### Como executar

No GitHub, acesse:

**Actions → Check Server → Run workflow**

O workflow executa:

```bash
chmod +x scripts/check-server.sh
./scripts/check-server.sh
```

### Resultado esperado

Se todos os requisitos forem atendidos, o workflow exibirá:

```text
SERVIDOR PRONTO

Todos os pré-requisitos verificados foram atendidos.
```

Se algum requisito não for atendido, o workflow exibirá:

```text
SERVIDOR NÃO ESTÁ PRONTO
```

Nesse caso, o processo deve ser interrompido e o problema indicado no resultado deve ser corrigido antes de executar o **Provision Server**.

### Importante

O **Check Server** é uma etapa de validação.

Ele não:

- cria diretórios de aplicação;
- cria os ambientes TEST e PROD;
- cria serviços `systemd`;
- configura permissões específicas de `sudo`;
- inicia as aplicações;
- faz deploy.

Essas tarefas pertencem às etapas seguintes do processo, principalmente ao **Provision Server** e ao **Deploy**.
