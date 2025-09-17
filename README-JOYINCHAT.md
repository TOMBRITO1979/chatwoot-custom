# 🚀 JoyInChat Chatwoot - Deploy Completo

Deploy customizado do Chatwoot para **chat.joyinchat.com** com Docker + Traefik + SSL automático.

## ⚡ Deploy Rápido (Executar na VPS)

```bash
# 1. Clone o repositório
git clone https://github.com/TOMBRITO1979/chatwoot-custom.git
cd chatwoot-custom

# 2. Deploy completo
chmod +x deploy-local.sh
./deploy-local.sh
```

## 🌍 Configuração JoyInChat

- **Domínio:** `chat.joyinchat.com`
- **Email:** `wasolutionscorp@gmail.com`
- **Organização:** JoyInChat
- **Imagem Docker:** `tomautomations/joyinchat:latest`

## 📋 Pré-requisitos na VPS

### 1. DNS
Configure seu DNS apontando para o IP da VPS:
```
chat.joyinchat.com           A    IP_DA_VPS
traefik.chat.joyinchat.com   A    IP_DA_VPS
```

### 2. Firewall
```bash
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw enable
```

### 3. Docker (se não instalado)
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

## 🛠️ Arquivos Principais

- **`deploy-local.sh`** - Script de deploy principal
- **`docker-compose.joyinchat.yml`** - Stack específica do JoyInChat
- **`.env.production`** - Configurações do ambiente
- **`Dockerfile.production`** - Build otimizado
- **Imagem base:** `tomautomations/joyinchat:latest` (já existente)

## 🔐 Credenciais Geradas

### PostgreSQL
- **Banco:** `chatwoot_production`
- **Usuário:** `chatwoot`
- **Senha:** `PG_98kL2mN5vX9qR4wE7tY1uI6oP3sA8dF2gH5jK9lM0`

### Redis
- **Senha:** `RD_47nB6xV8cZ2qW5eR9tY3uI7oP1sA4dF8gH2jK6lM9`

### Rails
- **SECRET_KEY_BASE:** Configurado automaticamente

## 📊 Serviços Incluídos

### Traefik (Proxy + SSL)
- **URL:** `http://traefik.chat.joyinchat.com:8080`
- SSL automático via Let's Encrypt
- Redirecionamento HTTP → HTTPS

### PostgreSQL 16 + pgvector
- Banco principal com extensões para IA
- Volumes persistentes
- Health checks

### Redis 7
- Cache e filas de background jobs
- Persistência ativada
- Autenticação configurada

### JoyInChat App
- **URL:** `https://chat.joyinchat.com`
- Baseado na imagem `tomautomations/joyinchat:latest`
- Health checks configurados
- Variáveis de ambiente otimizadas

### Sidekiq Worker
- Processamento de background jobs
- Mesma imagem base
- Monitoramento de processo

## 🚀 Execução na VPS

### Opção 1: Script Automatizado
```bash
# Na sua VPS
git clone https://github.com/TOMBRITO1979/chatwoot-custom.git
cd chatwoot-custom
./deploy-local.sh
```

### Opção 2: Comando Direto
```bash
curl -sSL https://raw.githubusercontent.com/TOMBRITO1979/chatwoot-custom/main/deploy-local.sh | bash
```

## 📚 Comandos Úteis

### Logs
```bash
# Todos os serviços
docker-compose -f docker-compose.joyinchat.yml logs -f

# Apenas app
docker-compose -f docker-compose.joyinchat.yml logs -f joyinchat

# Apenas Sidekiq
docker-compose -f docker-compose.joyinchat.yml logs -f sidekiq
```

### Gerenciamento
```bash
# Status dos serviços
docker-compose -f docker-compose.joyinchat.yml ps

# Restart de um serviço
docker-compose -f docker-compose.joyinchat.yml restart joyinchat

# Parar tudo
docker-compose -f docker-compose.joyinchat.yml down

# Iniciar tudo
docker-compose -f docker-compose.joyinchat.yml up -d
```

### Shell e Console
```bash
# Shell no container
docker exec -it joyinchat-app /bin/sh

# Console Rails
docker exec -it joyinchat-app bundle exec rails console

# Migrations
docker exec joyinchat-app bundle exec rails db:migrate

# Seed (criar conta admin)
docker exec joyinchat-app bundle exec rails db:seed
```

### Backup
```bash
# Backup do banco
docker exec joyinchat-postgres pg_dump -U chatwoot chatwoot_production > backup-$(date +%Y%m%d).sql

# Restaurar backup
docker exec -i joyinchat-postgres psql -U chatwoot -d chatwoot_production < backup-file.sql
```

## 🔧 Configurações Adicionais

### SMTP (Email)
Para configurar envio de emails, edite as variáveis no `docker-compose.joyinchat.yml`:

```yaml
environment:
  - SMTP_ADDRESS=smtp.gmail.com
  - SMTP_PORT=587
  - SMTP_EMAIL=wasolutionscorp@gmail.com
  - SMTP_PASSWORD=sua_senha_app_gmail
  - SMTP_ENABLE_STARTTLS_AUTO=true
```

### Storage S3 (Opcional)
Para usar S3 em vez de storage local:

```yaml
environment:
  - ACTIVE_STORAGE_SERVICE=amazon
  - AWS_ACCESS_KEY_ID=sua_access_key
  - AWS_SECRET_ACCESS_KEY=sua_secret_key
  - AWS_REGION=us-east-1
  - AWS_BUCKET=joyinchat-storage
```

## 🚨 Troubleshooting

### 1. SSL não funciona
- Verifique DNS: `nslookup chat.joyinchat.com`
- Aguarde propagação (até 24h)
- Verifique portas 80/443 liberadas

### 2. App não inicia
```bash
# Ver logs
docker-compose -f docker-compose.joyinchat.yml logs joyinchat

# Verificar migrations
docker exec joyinchat-app bundle exec rails db:migrate:status
```

### 3. Banco de dados
```bash
# Conectar ao banco
docker exec -it joyinchat-postgres psql -U chatwoot -d chatwoot_production

# Verificar conexão
docker exec joyinchat-app bundle exec rails db:version
```

### 4. Redis
```bash
# Conectar ao Redis
docker exec -it joyinchat-redis redis-cli -a RD_47nB6xV8cZ2qW5eR9tY3uI7oP1sA4dF8gH2jK6lM9

# Verificar jobs
docker exec joyinchat-app bundle exec rails console
> Sidekiq.redis_info
```

## 🔄 Atualizações

### Atualizar código
```bash
git pull
docker-compose -f docker-compose.joyinchat.yml restart joyinchat sidekiq
```

### Rebuild imagem (se necessário)
```bash
docker build -f Dockerfile.production -t tomautomations/joyinchat:latest .
docker-compose -f docker-compose.joyinchat.yml up -d
```

## 📈 Monitoramento

### Recursos do sistema
```bash
# Uso de recursos
docker stats

# Espaço em disco
df -h
docker system df
```

### Health checks
```bash
# Status da aplicação
curl -f https://chat.joyinchat.com/health

# Status SSL
echo | openssl s_client -connect chat.joyinchat.com:443 | openssl x509 -noout -dates
```

## 🎯 Próximos Passos

1. ✅ **Execute o deploy:** `./deploy-local.sh`
2. ✅ **Configure DNS:** Aponte `chat.joyinchat.com` para sua VPS
3. ✅ **Aguarde SSL:** Let's Encrypt criará certificados automaticamente
4. ✅ **Execute seed:** `docker exec joyinchat-app bundle exec rails db:seed`
5. ✅ **Acesse:** `https://chat.joyinchat.com`
6. ✅ **Configure SMTP:** Para envio de emails
7. ✅ **Backup automático:** Configure cronjob para backups

---

**🚀 JoyInChat está pronto para voar!** 🎉

Para suporte: `wasolutionscorp@gmail.com`