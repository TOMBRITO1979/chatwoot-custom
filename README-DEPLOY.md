# 🚀 Chatwoot Deploy - Docker + Traefik + SSL

Deploy completo do Chatwoot customizado com SSL automático, PostgreSQL e Redis.

## ⚡ Deploy Rápido (Uma linha)

```bash
curl -sSL https://raw.githubusercontent.com/SEU_USUARIO/chatwoot-custom/main/deploy.sh | bash -s -- \
  --domain=suaempresa.com \
  --email=admin@suaempresa.com \
  --docker-user=seu_usuario_docker \
  --docker-pass=sua_senha_docker
```

## 🛠️ Deploy Manual

### 1. Configuração

```bash
# Clone do repositório
git clone https://github.com/SEU_USUARIO/chatwoot-custom.git
cd chatwoot-custom

# Configurar ambiente
cp .env.production.template .env.production
# Edite o arquivo .env.production com suas configurações
```

### 2. Build e Deploy

```bash
# Deploy completo
chmod +x build-and-deploy.sh
./build-and-deploy.sh

# OU usando Make
make setup
make build
```

### 3. Comandos Úteis

```bash
# Ver logs
make logs

# Status dos serviços
make status

# Shell no container
make shell

# Migrations
make db-migrate

# Seed inicial
make db-seed

# Backup
make backup

# Deploy rápido (sem build)
make quick-deploy
```

## 📋 Arquivos Criados

- **`Dockerfile.production`** - Build otimizado para produção
- **`docker-compose.production.yml`** - Stack completa com Traefik
- **`.env.production`** - Configurações de ambiente
- **`build-and-deploy.sh`** - Script completo de build e deploy
- **`quick-deploy.sh`** - Deploy rápido sem build
- **`Makefile.docker`** - Comandos úteis

## 🌍 Componentes

### Traefik (Reverse Proxy)
- SSL automático com Let's Encrypt
- Dashboard em `http://traefik.SEUDOMINIO:8080`
- Roteamento automático

### PostgreSQL
- Banco principal com pgvector
- Volumes persistentes
- Health checks

### Redis
- Cache e filas de job
- Autenticação por senha
- Volumes persistentes

### Chatwoot
- Build multi-stage otimizado
- Health checks
- Logs estruturados
- Escalabilidade horizontal

## ⚙️ Configurações

### DNS
Configure seu DNS apontando para o IP da VPS:
```
SEUDOMINIO.com     A    IP_DA_VPS
traefik.SEUDOMINIO.com A IP_DA_VPS
```

### Firewall
Libere as portas necessárias:
```bash
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw enable
```

### SMTP (Email)
Edite `.env.production`:
```bash
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_EMAIL=seu_email@gmail.com
SMTP_PASSWORD=sua_senha_app
```

## 🔒 Segurança

### Senhas Geradas
O script gera automaticamente senhas seguras para:
- PostgreSQL
- Redis
- Rails SECRET_KEY_BASE

### SSL/TLS
- Certificados automáticos via Let's Encrypt
- Redirecionamento HTTP → HTTPS
- Headers de segurança

### Container Security
- Usuário não-root no container
- Volumes com permissões restritas
- Networks isoladas

## 📊 Monitoramento

### Logs
```bash
# Todos os serviços
make logs

# Apenas app
make logs-app

# Apenas Sidekiq
make logs-sidekiq
```

### Health Checks
```bash
# Status geral
make status

# Verificar saúde
make health

# SSL
make ssl-check
```

### Backup
```bash
# Backup manual
make backup

# Restaurar backup
make restore BACKUP_FILE=backup-20231201-120000.sql
```

## 🚨 Troubleshooting

### Problemas Comuns

**1. SSL não funciona**
- Verifique DNS apontando para VPS
- Aguarde propagação (até 24h)
- Verifique firewall (portas 80, 443)

**2. Aplicação não inicia**
```bash
make logs-app
# Verifique migrations
make db-migrate
```

**3. Email não funciona**
- Configure SMTP no `.env.production`
- Reinicie: `make restart`

**4. Performance**
```bash
# Verificar recursos
docker stats

# Logs de erro
make logs | grep ERROR
```

### Reset Completo
```bash
# CUIDADO: Remove todos os dados
make clean-all
```

## 📈 Escalabilidade

### Horizontal Scaling
```bash
# Adicionar mais workers Sidekiq
docker-compose -f docker-compose.production.yml up -d --scale sidekiq=3
```

### Load Balancer
O Traefik suporta múltiplas instâncias automaticamente.

## 🔄 Atualizações

```bash
# Atualizar código
git pull

# Rebuild e deploy
make build

# OU apenas atualizar imagem
make update
```

## 📞 Suporte

- **Logs**: `make logs`
- **Status**: `make status`
- **Shell**: `make shell`
- **Console Rails**: `make shell-rails`

## 🎯 Próximos Passos

1. ✅ Configure DNS
2. ✅ Execute `make db-migrate`
3. ✅ Execute `make db-seed`
4. ✅ Configure SMTP
5. ✅ Crie conta admin
6. ✅ Configure backup automático
7. ✅ Configure monitoramento

---

**🚀 Happy Deploying!**