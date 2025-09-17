#!/bin/bash

# ======================================
# DEPLOY PRINCIPAL - CHATWOOT CUSTOMIZADO
# ======================================
# Script para execução completa via curl

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 CHATWOOT DEPLOY TOOL 🚀                   ║"
    echo "║                                                                  ║"
    echo "║  Deploy completo com Docker + Traefik + SSL + PostgreSQL        ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Logging
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Verificar se é root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Executando como root. Considere usar um usuário com sudo."
    fi
}

# Verificar sistema operacional
check_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log "✅ Sistema Linux detectado"
    else
        warn "Sistema não testado. Pode haver problemas."
    fi
}

# Instalar dependências
install_dependencies() {
    log "📦 Verificando dependências..."

    # Docker
    if ! command -v docker &> /dev/null; then
        log "Instalando Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        usermod -aG docker $USER || true
        rm get-docker.sh
        log "✅ Docker instalado"
    else
        log "✅ Docker já instalado"
    fi

    # Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "Instalando Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log "✅ Docker Compose instalado"
    else
        log "✅ Docker Compose já instalado"
    fi

    # Git
    if ! command -v git &> /dev/null; then
        log "Instalando Git..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y git
        elif command -v yum &> /dev/null; then
            yum install -y git
        else
            error "Não foi possível instalar Git automaticamente"
        fi
        log "✅ Git instalado"
    else
        log "✅ Git já instalado"
    fi

    # Ferramentas essenciais
    if ! command -v curl &> /dev/null || ! command -v openssl &> /dev/null; then
        log "Instalando ferramentas essenciais..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y curl openssl
        elif command -v yum &> /dev/null; then
            yum install -y curl openssl
        fi
    fi
}

# Configuração interativa
interactive_setup() {
    log "⚙️ Configuração interativa"
    echo ""

    # Domínio
    read -p "🌍 Digite seu domínio (ex: chatwoot.exemplo.com): " DOMAIN
    [ -z "$DOMAIN" ] && error "Domínio é obrigatório"

    # Email para SSL
    read -p "📧 Digite seu email para SSL (Let's Encrypt): " ACME_EMAIL
    [ -z "$ACME_EMAIL" ] && error "Email é obrigatório"

    # Docker Hub
    read -p "🐳 Digite seu usuário do Docker Hub: " DOCKER_USERNAME
    [ -z "$DOCKER_USERNAME" ] && error "Usuário Docker Hub é obrigatório"

    read -s -p "🔐 Digite sua senha do Docker Hub: " DOCKER_PASSWORD
    echo ""

    # GitHub (opcional)
    read -p "🐙 Digite seu token do GitHub (opcional, ENTER para pular): " GITHUB_TOKEN

    # Gerar senhas
    log "🔑 Gerando senhas seguras..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32)
    REDIS_PASSWORD=$(openssl rand -base64 32)
    SECRET_KEY_BASE=$(openssl rand -hex 64)

    log "✅ Configuração concluída"
}

# Criar arquivo .env
create_env_file() {
    log "📝 Criando arquivo .env.production..."

    cat > .env.production << EOF
# ======================================
# CONFIGURAÇÃO DE PRODUÇÃO - CHATWOOT
# ======================================

# DOMÍNIO E SSL
DOMAIN=${DOMAIN}
ACME_EMAIL=${ACME_EMAIL}

# DOCKER HUB
DOCKER_USERNAME=${DOCKER_USERNAME}
DOCKER_PASSWORD=${DOCKER_PASSWORD}

# BANCO DE DADOS POSTGRESQL
POSTGRES_DB=chatwoot_production
POSTGRES_USER=chatwoot
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# REDIS
REDIS_PASSWORD=${REDIS_PASSWORD}

# RAILS
SECRET_KEY_BASE=${SECRET_KEY_BASE}
RAILS_ENV=production

# EMAIL/SMTP (configure depois)
MAILER_SENDER_EMAIL=noreply@${DOMAIN}
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_EMAIL=
SMTP_PASSWORD=

# STORAGE
ACTIVE_STORAGE_SERVICE=local
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=
AWS_BUCKET=

# FEATURES
ENABLE_ACCOUNT_SIGNUP=false
INSTALLATION_NAME=Chatwoot
EOF

    log "✅ Arquivo .env.production criado"
}

# Setup do GitHub
setup_github() {
    if [ -n "${GITHUB_TOKEN}" ]; then
        log "🐙 Configurando GitHub..."

        git config --global user.email "${ACME_EMAIL}"
        git config --global user.name "Chatwoot Deploy"

        # Clone do repositório se não existe
        if [ ! -d ".git" ]; then
            git init
            git remote add origin "https://${GITHUB_TOKEN}@github.com/${DOCKER_USERNAME}/chatwoot-custom.git" 2>/dev/null || true
        fi

        log "✅ GitHub configurado"
    else
        log "⏭️ Pulando configuração do GitHub"
    fi
}

# Executar deploy
run_deploy() {
    log "🚀 Iniciando deploy..."

    # Tornar scripts executáveis
    chmod +x *.sh

    # Executar build e deploy
    export DOCKER_PASSWORD
    export GITHUB_TOKEN
    ./build-and-deploy.sh

    log "✅ Deploy concluído!"
}

# Mostrar informações finais
show_final_info() {
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                    🎉 DEPLOY CONCLUÍDO! 🎉                       ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}🌍 URL Principal:${NC} https://${DOMAIN}"
    echo -e "${GREEN}📊 Traefik Dashboard:${NC} http://traefik.${DOMAIN}:8080"
    echo -e "${GREEN}🐳 Imagem Docker:${NC} ${DOCKER_USERNAME}/chatwoot:latest"
    echo ""
    echo -e "${YELLOW}📋 PRÓXIMOS PASSOS:${NC}"
    echo "1. Configure DNS: ${DOMAIN} → IP do servidor"
    echo "2. Configure firewall: portas 80, 443, 22"
    echo "3. Execute migrations:"
    echo "   make db-migrate"
    echo "4. Crie conta admin:"
    echo "   make db-seed"
    echo "5. Configure SMTP no .env.production"
    echo ""
    echo -e "${BLUE}📚 COMANDOS ÚTEIS:${NC}"
    echo "make logs          # Ver logs"
    echo "make status        # Status dos serviços"
    echo "make shell         # Shell no container"
    echo "make backup        # Backup do banco"
    echo "make quick-deploy  # Deploy rápido"
    echo ""
    echo -e "${GREEN}📁 Arquivos criados:${NC}"
    echo "- Dockerfile.production"
    echo "- docker-compose.production.yml"
    echo "- .env.production"
    echo "- build-and-deploy.sh"
    echo "- Makefile.docker"
    echo ""
    echo -e "${PURPLE}🔐 SENHAS GERADAS (salve em local seguro):${NC}"
    echo "PostgreSQL: ${POSTGRES_PASSWORD}"
    echo "Redis: ${REDIS_PASSWORD}"
    echo ""
}

# Configuração não interativa (via parâmetros)
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain=*)
                DOMAIN="${1#*=}"
                shift
                ;;
            --email=*)
                ACME_EMAIL="${1#*=}"
                shift
                ;;
            --docker-user=*)
                DOCKER_USERNAME="${1#*=}"
                shift
                ;;
            --docker-pass=*)
                DOCKER_PASSWORD="${1#*=}"
                shift
                ;;
            --github-token=*)
                GITHUB_TOKEN="${1#*=}"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Parâmetro desconhecido: $1"
                ;;
        esac
    done
}

# Ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Opções:"
    echo "  --domain=DOMAIN        Domínio para o Chatwoot"
    echo "  --email=EMAIL          Email para Let's Encrypt"
    echo "  --docker-user=USER     Usuário do Docker Hub"
    echo "  --docker-pass=PASS     Senha do Docker Hub"
    echo "  --github-token=TOKEN   Token do GitHub (opcional)"
    echo "  --help                 Mostrar esta ajuda"
    echo ""
    echo "Exemplo:"
    echo "  $0 --domain=chat.exemplo.com --email=admin@exemplo.com --docker-user=meuuser --docker-pass=minhasenha"
}

# Função principal
main() {
    show_banner
    check_root
    check_os

    # Parse dos argumentos
    parse_args "$@"

    # Se não tem parâmetros obrigatórios, modo interativo
    if [ -z "${DOMAIN:-}" ]; then
        interactive_setup
    else
        # Validar parâmetros obrigatórios
        [ -z "${ACME_EMAIL:-}" ] && error "Email é obrigatório (--email)"
        [ -z "${DOCKER_USERNAME:-}" ] && error "Usuário Docker é obrigatório (--docker-user)"
        [ -z "${DOCKER_PASSWORD:-}" ] && error "Senha Docker é obrigatória (--docker-pass)"

        # Gerar senhas se não fornecidas
        POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 32)}
        REDIS_PASSWORD=${REDIS_PASSWORD:-$(openssl rand -base64 32)}
        SECRET_KEY_BASE=${SECRET_KEY_BASE:-$(openssl rand -hex 64)}
    fi

    install_dependencies
    create_env_file
    setup_github
    run_deploy
    show_final_info
}

# Executar se for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi