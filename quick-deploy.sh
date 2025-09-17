#!/bin/bash

# ======================================
# QUICK DEPLOY - CHATWOOT CUSTOMIZADO
# ======================================
# Script para deploy rápido usando imagem já buildada

set -euo pipefail

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Função principal
main() {
    log "🚀 Quick Deploy - Chatwoot"

    # Verificar .env
    if [ ! -f .env.production ]; then
        error "Arquivo .env.production não encontrado. Execute build-and-deploy.sh primeiro."
    fi

    # Carregar variáveis
    set -a; source .env.production; set +a

    # Verificar variáveis essenciais
    [ -z "${DOMAIN:-}" ] && error "DOMAIN não definido"
    [ -z "${DOCKER_USERNAME:-}" ] && error "DOCKER_USERNAME não definido"

    # Criar rede se necessário
    if ! docker network ls | grep -q "public"; then
        docker network create public
        log "✅ Rede 'public' criada"
    fi

    # Deploy
    log "📦 Fazendo pull da imagem mais recente..."
    docker-compose -f docker-compose.production.yml pull

    log "🔄 Reiniciando serviços..."
    docker-compose -f docker-compose.production.yml down
    docker-compose -f docker-compose.production.yml up -d

    log "⏳ Aguardando inicialização..."
    sleep 30

    # Verificar
    if curl -f -s "https://${DOMAIN}/health" >/dev/null 2>&1; then
        log "✅ Deploy concluído! Acesse: https://${DOMAIN}"
    else
        warn "❌ Aplicação pode não estar respondendo ainda. Verifique logs:"
        echo "docker-compose -f docker-compose.production.yml logs -f chatwoot"
    fi
}

main "$@"