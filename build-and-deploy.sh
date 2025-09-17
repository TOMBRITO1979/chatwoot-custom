#!/bin/bash

# ======================================
# SCRIPT DE BUILD E DEPLOY - CHATWOOT
# ======================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar dependências
check_dependencies() {
    log "Verificando dependências..."

    if ! command_exists docker; then
        error "Docker não está instalado. Instale o Docker primeiro."
    fi

    if ! command_exists git; then
        error "Git não está instalado."
    fi

    log "✅ Dependências verificadas"
}

# Configurar variáveis
setup_variables() {
    log "Configurando variáveis de ambiente..."

    # Carregar .env se existir
    if [ -f .env.production ]; then
        set -a
        source .env.production
        set +a
        log "✅ Arquivo .env.production carregado"
    else
        warn "Arquivo .env.production não encontrado. Criando um template..."
        cp .env.production.template .env.production
        error "Configure o arquivo .env.production e execute novamente"
    fi

    # Verificar variáveis obrigatórias
    REQUIRED_VARS=(
        "DOMAIN"
        "DOCKER_USERNAME"
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "SECRET_KEY_BASE"
    )

    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var:-}" ]; then
            error "Variável $var não está definida no .env.production"
        fi
    done

    # Definir tag da imagem
    if [ -n "${1:-}" ]; then
        IMAGE_TAG="$1"
    else
        IMAGE_TAG="$(date +%Y%m%d)-$(git rev-parse --short HEAD 2>/dev/null || echo 'custom')"
    fi

    DOCKER_IMAGE="${DOCKER_USERNAME}/chatwoot:${IMAGE_TAG}"
    DOCKER_IMAGE_LATEST="${DOCKER_USERNAME}/chatwoot:latest"

    log "📦 Imagem Docker: ${DOCKER_IMAGE}"
}

# Build da imagem Docker
build_image() {
    log "🔨 Iniciando build da imagem Docker..."

    # Build da imagem
    docker build \
        -f Dockerfile.production \
        -t "${DOCKER_IMAGE}" \
        -t "${DOCKER_IMAGE_LATEST}" \
        --build-arg RAILS_ENV=production \
        .

    log "✅ Build concluído: ${DOCKER_IMAGE}"
}

# Login no Docker Hub
docker_login() {
    log "🔐 Fazendo login no Docker Hub..."

    if [ -n "${DOCKER_PASSWORD:-}" ]; then
        echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
    else
        docker login -u "${DOCKER_USERNAME}"
    fi

    log "✅ Login no Docker Hub realizado"
}

# Push para Docker Hub
push_image() {
    log "📤 Enviando imagem para Docker Hub..."

    docker push "${DOCKER_IMAGE}"
    docker push "${DOCKER_IMAGE_LATEST}"

    log "✅ Imagem enviada: ${DOCKER_IMAGE}"
}

# Commit e push para GitHub
push_to_github() {
    log "📤 Enviando para GitHub..."

    # Verificar se há mudanças
    if git diff --quiet && git diff --staged --quiet; then
        warn "Nenhuma mudança para commitar"
        return
    fi

    # Add, commit e push
    git add .
    git commit -m "🚀 Deploy: versão ${IMAGE_TAG}

- Build Docker otimizado para produção
- Configuração Traefik com SSL automático
- PostgreSQL com pgvector
- Redis para cache e jobs
- Stack completo para deploy

🐳 Imagem: ${DOCKER_IMAGE}"

    # Push para branch atual
    CURRENT_BRANCH=$(git branch --show-current)
    git push origin "${CURRENT_BRANCH}"

    log "✅ Código enviado para GitHub (branch: ${CURRENT_BRANCH})"
}

# Criar rede Docker se não existir
setup_network() {
    log "🌐 Configurando rede Docker..."

    if ! docker network ls | grep -q "public"; then
        docker network create public
        log "✅ Rede 'public' criada"
    else
        log "✅ Rede 'public' já existe"
    fi
}

# Deploy da stack
deploy_stack() {
    log "🚀 Fazendo deploy da stack..."

    # Parar serviços existentes
    if [ -f docker-compose.production.yml ]; then
        docker-compose -f docker-compose.production.yml down || true
    fi

    # Atualizar imagem no docker-compose
    export DOCKER_USERNAME
    export IMAGE_TAG

    # Iniciar serviços
    docker-compose -f docker-compose.production.yml pull
    docker-compose -f docker-compose.production.yml up -d

    log "✅ Stack deployada com sucesso!"
    log "🌍 Acesse: https://${DOMAIN}"
    log "📊 Traefik Dashboard: http://traefik.${DOMAIN}:8080"
}

# Verificar saúde dos serviços
check_health() {
    log "🔍 Verificando saúde dos serviços..."

    sleep 30  # Aguardar inicialização

    # Verificar se os containers estão rodando
    SERVICES=("chatwoot-postgres" "chatwoot-redis" "chatwoot-app" "chatwoot-sidekiq" "chatwoot-traefik")

    for service in "${SERVICES[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "$service"; then
            log "✅ $service está rodando"
        else
            warn "❌ $service não está rodando"
        fi
    done

    # Teste HTTP
    if curl -f -s "https://${DOMAIN}/health" >/dev/null; then
        log "✅ Aplicação respondendo em https://${DOMAIN}"
    else
        warn "❌ Aplicação não está respondendo"
    fi
}

# Função principal
main() {
    log "🚀 Iniciando processo de build e deploy..."

    check_dependencies
    setup_variables "$@"
    build_image

    # Docker Hub
    if [ "${SKIP_DOCKER_PUSH:-false}" != "true" ]; then
        docker_login
        push_image
    fi

    # GitHub
    if [ "${SKIP_GITHUB_PUSH:-false}" != "true" ]; then
        push_to_github
    fi

    # Deploy
    if [ "${SKIP_DEPLOY:-false}" != "true" ]; then
        setup_network
        deploy_stack
        check_health
    fi

    log "🎉 Processo concluído com sucesso!"
    echo ""
    echo "📋 RESUMO:"
    echo "🐳 Imagem Docker: ${DOCKER_IMAGE}"
    echo "🌍 URL: https://${DOMAIN}"
    echo "📊 Traefik: http://traefik.${DOMAIN}:8080"
    echo ""
    echo "📚 PRÓXIMOS PASSOS:"
    echo "1. Configure DNS apontando ${DOMAIN} para sua VPS"
    echo "2. Configure firewall (portas 80, 443)"
    echo "3. Execute migrations: docker exec chatwoot-app rails db:create db:migrate"
    echo "4. Crie conta admin: docker exec chatwoot-app rails db:seed"
}

# Ajuda
show_help() {
    echo "Uso: $0 [TAG] [OPÇÕES]"
    echo ""
    echo "Argumentos:"
    echo "  TAG                    Tag da imagem Docker (padrão: data-commit)"
    echo ""
    echo "Variáveis de ambiente:"
    echo "  SKIP_DOCKER_PUSH=true  Pular push para Docker Hub"
    echo "  SKIP_GITHUB_PUSH=true  Pular push para GitHub"
    echo "  SKIP_DEPLOY=true       Pular deploy local"
    echo "  DOCKER_PASSWORD        Senha do Docker Hub (evita prompt)"
    echo ""
    echo "Exemplos:"
    echo "  $0                     # Build com tag automática"
    echo "  $0 v1.2.3             # Build com tag específica"
    echo "  SKIP_DEPLOY=true $0    # Apenas build e push"
}

# Verificar argumentos
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_help
    exit 0
fi

# Executar função principal
main "$@"