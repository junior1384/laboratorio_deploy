1. Cria os diretórios dos ambientes

Cria:

/var/www/
├── deploy-lab-test/
│ └── releases/
└── deploy-lab-prod/
└── releases/

A ideia é manter TEST e PROD separados e guardar versões/releases.

2. Configura o dono dos diretórios

Define juniorwinkler como proprietário desses diretórios, para que o Runner consiga trabalhar neles.

3. Configura o sudo para operações específicas

Cria:

/etc/sudoers.d/laboratorio-deploy

E permite que o usuário do Runner execute determinados comandos systemctl sem precisar digitar senha.

Por exemplo:

systemctl start deploy-lab-test.service
systemctl restart deploy-lab-test.service
systemctl status deploy-lab-test.service

Isso é importante porque o GitHub Actions não pode ficar esperando uma senha durante o workflow.

4. Cria os serviços systemd

Cria:

/etc/systemd/system/deploy-lab-test.service
/etc/systemd/system/deploy-lab-prod.service

Eles representam as duas instâncias da aplicação:

TEST → porta 5001
PROD → porta 5002

E definem que a aplicação será executada como:

juniorwinkler 5. Habilita os serviços

Executa o equivalente a:

systemctl enable deploy-lab-test.service
systemctl enable deploy-lab-prod.service

Isso faz com que os serviços sejam configurados para iniciar junto com o sistema.

6. Garante que o Runner tenha serviço

O script verifica se o GitHub Actions Runner já está instalado como serviço.

Se não estiver, ele instala:

actions.runner.junior1384-laboratorio_deploy.laboratorio-deploy-runner.service

E habilita esse serviço.

7. Valida a configuração

No final, ele verifica:

diretórios;
serviços;
configuração do sudo;
configuração do systemd;
serviço do Runner.
