#!/bin/bash

# ======================================
# DEPLOY LOCAL - CHATWOOT JOYINCHAT
# ======================================
# Script para deploy usando imagem Docker local existente

set -euo pipefail

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                🚀 JOYINCHAT CHATWOOT DEPLOY 🚀                  ║"
echo "║                                                                  ║"
echo "║  Deploy usando imagem Docker local existente                     ║"
echo "║  Domain: chat.joyinchat.com                                      ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar se imagem existe
if ! docker images | grep -q "tomautomations/joyinchat"; then
    error "Imagem tomautomations/joyinchat não encontrada. Execute o build primeiro."
fi

log "✅ Imagem Docker encontrada"

# Preparar docker-compose para usar imagem local
log "📝 Preparando docker-compose para imagem local..."

# Criar docker-compose específico para deploy local
cat > docker-compose.joyinchat.yml << 'EOF'
version: '3.8'

networks:
  public:
    external: true
  joyinchat-internal:
    driver: bridge

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  traefik_data:
    driver: local

services:
  # Traefik - Reverse Proxy com SSL automático
  traefik:
    image: traefik:v3.0
    container_name: joyinchat-traefik
    restart: unless-stopped
    networks:
      - public
      - joyinchat-internal
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_data:/letsencrypt
    command:
      - --api.dashboard=true
      - --api.insecure=true
      - --log.level=INFO
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=public
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.email=wasolutionscorp@gmail.com
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --certificatesresolvers.letsencrypt.acme.httpchallenge=true
      - --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.chat.joyinchat.com`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"

  # PostgreSQL com pgvector
  postgres:
    image: pgvector/pgvector:pg16
    container_name: joyinchat-postgres
    restart: unless-stopped
    networks:
      - joyinchat-internal
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=chatwoot_production
      - POSTGRES_USER=chatwoot
      - POSTGRES_PASSWORD=PG_98kL2mN5vX9qR4wE7tY1uI6oP3sA8dF2gH5jK9lM0
      - POSTGRES_HOST_AUTH_METHOD=md5
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U chatwoot"]
      interval: 30s
      timeout: 10s
      retries: 5
    labels:
      - "traefik.enable=false"

  # Redis
  redis:
    image: redis:7-alpine
    container_name: joyinchat-redis
    restart: unless-stopped
    networks:
      - joyinchat-internal
    volumes:
      - redis_data:/data
    command: redis-server --requirepass RD_47nB6xV8cZ2qW5eR9tY3uI7oP1sA4dF8gH2jK6lM9 --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5
    labels:
      - "traefik.enable=false"

  # JoyInChat App
  joyinchat:
    image: tomautomations/joyinchat:latest
    container_name: joyinchat-app
    restart: unless-stopped
    networks:
      - public
      - joyinchat-internal
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678
      - FRONTEND_URL=https://chat.joyinchat.com
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DATABASE=chatwoot_production
      - POSTGRES_USERNAME=chatwoot
      - POSTGRES_PASSWORD=PG_98kL2mN5vX9qR4wE7tY1uI6oP3sA8dF2gH5jK9lM0
      - REDIS_URL=redis://:RD_47nB6xV8cZ2qW5eR9tY3uI7oP1sA4dF8gH2jK6lM9@redis:6379
      - MAILER_SENDER_EMAIL=noreply@chat.joyinchat.com
      - ACTIVE_STORAGE_SERVICE=local
      - ENABLE_ACCOUNT_SIGNUP=false
      - INSTALLATION_NAME=JoyInChat
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=public"
      - "traefik.http.routers.joyinchat.rule=Host(`chat.joyinchat.com`)"
      - "traefik.http.routers.joyinchat.entrypoints=websecure"
      - "traefik.http.routers.joyinchat.tls.certresolver=letsencrypt"
      - "traefik.http.services.joyinchat.loadbalancer.server.port=3000"
      - "traefik.http.middlewares.joyinchat-headers.headers.forceSTSHeader=true"
      - "traefik.http.middlewares.joyinchat-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.joyinchat-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.joyinchat-headers.headers.stsPreload=true"
      - "traefik.http.routers.joyinchat.middlewares=joyinchat-headers"

  # Sidekiq Worker
  sidekiq:
    image: tomautomations/joyinchat:latest
    container_name: joyinchat-sidekiq
    restart: unless-stopped
    networks:
      - joyinchat-internal
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DATABASE=chatwoot_production
      - POSTGRES_USERNAME=chatwoot
      - POSTGRES_PASSWORD=PG_98kL2mN5vX9qR4wE7tY1uI6oP3sA8dF2gH5jK9lM0
      - REDIS_URL=redis://:RD_47nB6xV8cZ2qW5eR9tY3uI7oP1sA4dF8gH2jK6lM9@redis:6379
      - MAILER_SENDER_EMAIL=noreply@chat.joyinchat.com
      - ACTIVE_STORAGE_SERVICE=local
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    healthcheck:
      test: ["CMD", "ps", "aux", "|", "grep", "[s]idekiq"]
      interval: 30s
      timeout: 10s
      retries: 5
    labels:
      - "traefik.enable=false"
EOF

# Criar rede se não existir
log "🌐 Configurando rede Docker..."
if ! docker network ls | grep -q "public"; then
    docker network create public
    log "✅ Rede 'public' criada"
else
    log "✅ Rede 'public' já existe"
fi

# Parar serviços existentes
log "🔄 Parando serviços existentes..."
docker-compose -f docker-compose.joyinchat.yml down || true

# Iniciar serviços
log "🚀 Iniciando serviços JoyInChat..."
docker-compose -f docker-compose.joyinchat.yml up -d

log "⏳ Aguardando inicialização dos serviços..."
sleep 45

# Executar migrations
log "🗄️ Executando migrations..."
docker exec joyinchat-app bundle exec rails db:create db:migrate || warn "Erro nas migrations - verifique logs"

# Verificar saúde
log "🔍 Verificando serviços..."
docker-compose -f docker-compose.joyinchat.yml ps

echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║               🎉 JOYINCHAT DEPLOY CONCLUÍDO! 🎉                  ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}🌍 URL Principal:${NC} https://chat.joyinchat.com"
echo -e "${GREEN}📊 Traefik Dashboard:${NC} http://traefik.chat.joyinchat.com:8080"
echo -e "${GREEN}🐳 Imagem:${NC} tomautomations/joyinchat:latest"
echo ""
echo -e "${YELLOW}📋 PRÓXIMOS PASSOS:${NC}"
echo "1. Configure DNS: chat.joyinchat.com → IP do servidor"
echo "2. Configure firewall: portas 80, 443, 22"
echo "3. Crie conta admin:"
echo "   docker exec joyinchat-app bundle exec rails db:seed"
echo "4. Configure SMTP se necessário"
echo ""
echo -e "${BLUE}📚 COMANDOS ÚTEIS:${NC}"
echo "docker-compose -f docker-compose.joyinchat.yml logs -f        # Logs"
echo "docker-compose -f docker-compose.joyinchat.yml ps             # Status"
echo "docker exec -it joyinchat-app /bin/sh                         # Shell"
echo "docker exec joyinchat-app bundle exec rails console           # Console"
echo ""
echo -e "${GREEN}🔐 SENHAS SALVAS:${NC}"
echo "PostgreSQL: PG_98kL2mN5vX9qR4wE7tY1uI6oP3sA8dF2gH5jK9lM0"
echo "Redis: RD_47nB6xV8cZ2qW5eR9tY3uI7oP1sA4dF8gH2jK6lM9"
echo ""
EOF