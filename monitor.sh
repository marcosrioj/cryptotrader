#!/bin/bash
# Script de backup e monitoramento para FreqTrade
# Uso: ./monitor.sh

set -e

# Configurações
USER_DATA_DIR="/home/marcos/projects/cryptotrader/user_data"
PROJECT_DIR="/home/marcos/projects/cryptotrader"
BACKUP_DIR="/home/marcos/projects/cryptotrader/backups"
LOG_FILE="$USER_DATA_DIR/logs/freqtrade.log"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Função para fazer backup
backup_data() {
    log "Iniciando backup..."
    
    # Criar diretório de backup se não existir
    mkdir -p "$BACKUP_DIR/$(date +'%Y-%m')"
    
    BACKUP_FILE="$BACKUP_DIR/$(date +'%Y-%m')/backup_$(date +'%Y%m%d_%H%M%S').tar.gz"
    
    # Fazer backup dos dados importantes
    tar -czf "$BACKUP_FILE" \
        -C "$USER_DATA_DIR" \
        --exclude="logs/*.log*" \
        --exclude="data/*.json" \
        . 2>/dev/null || warning "Alguns arquivos podem não ter sido incluídos no backup"
    
    log "Backup criado: $BACKUP_FILE"
    
    # Limpar backups antigos (manter apenas últimos 30 dias)
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    log "Backups antigos removidos"
}

# Função para mostrar status
show_status() {
    info "=== STATUS DO FREQTRADE ==="
    
    # Verificar se FreqTrade está rodando
    if pgrep -f "freqtrade trade" > /dev/null; then
        log "✅ FreqTrade está rodando"
        
        # Mostrar informações dos processos
        info "Processos FreqTrade:"
        pgrep -f "freqtrade trade" | xargs ps -p | tail -n +2
        
    else
        warning "❌ FreqTrade não está rodando"
    fi
    
    echo ""
    
    # Verificar espaço em disco
    info "=== ESPAÇO EM DISCO ==="
    df -h "$USER_DATA_DIR" | tail -n 1 | awk '{print "Usado: " $3 " / " $2 " (" $5 ")"}'
    
    echo ""
    
    # Verificar logs recentes
    if [ -f "$LOG_FILE" ]; then
        info "=== ÚLTIMAS ENTRADAS DO LOG ==="
        tail -n 10 "$LOG_FILE" | while read line; do
            if echo "$line" | grep -q "ERROR"; then
                error "$line"
            elif echo "$line" | grep -q "WARNING"; then
                warning "$line"
            else
                echo "$line"
            fi
        done
    else
        warning "Arquivo de log não encontrado: $LOG_FILE"
    fi
    
    echo ""
    
    # Verificar trades recentes (se database existir)
    DB_FILE="$USER_DATA_DIR/tradesv3.sqlite"
    if [ -f "$DB_FILE" ]; then
        info "=== TRADES RECENTES ==="
        # Usar FreqTrade para mostrar trades (requer ambiente ativo)
        if command -v freqtrade &> /dev/null; then
            freqtrade show_trades --db-url "sqlite:///$DB_FILE" --days 1 2>/dev/null | tail -n 10 || warning "Não foi possível acessar dados de trades"
        else
            warning "FreqTrade não está no PATH atual"
        fi
    fi
}

# Função para monitoramento contínuo
monitor_continuous() {
    log "Iniciando monitoramento contínuo (Ctrl+C para parar)..."
    
    while true; do
        clear
        show_status
        
        info "Próxima atualização em 30 segundos..."
        sleep 30
    done
}

# Função para limpeza de logs
cleanup_logs() {
    log "Iniciando limpeza de logs..."
    
    # Compactar logs antigos
    find "$USER_DATA_DIR/logs" -name "*.log" -mtime +7 -exec gzip {} \;
    
    # Remover logs muito antigos
    find "$USER_DATA_DIR/logs" -name "*.log.gz" -mtime +30 -delete
    
    log "Limpeza de logs concluída"
}

# Função para verificar performance
check_performance() {
    info "=== ANÁLISE DE PERFORMANCE ==="
    
    DB_FILE="$USER_DATA_DIR/tradesv3.sqlite"
    if [ -f "$DB_FILE" ] && command -v freqtrade &> /dev/null; then
        
        # Performance dos últimos 7 dias
        info "Performance últimos 7 dias:"
        freqtrade show_trades --db-url "sqlite:///$DB_FILE" --days 7 2>/dev/null || warning "Erro ao acessar dados"
        
        echo ""
        
        # Performance por par
        info "Performance por par (últimos 30 dias):"
        freqtrade show_trades --db-url "sqlite:///$DB_FILE" --days 30 --print-json 2>/dev/null | \
        jq -r '.[] | "\(.pair): \(.profit_ratio * 100 | round)%"' 2>/dev/null | \
        sort | uniq -c | sort -nr || warning "jq não disponível para análise detalhada"
        
    else
        warning "Banco de dados de trades não encontrado ou FreqTrade não disponível"
    fi
}

# Menu principal
show_menu() {
    echo ""
    info "=== MONITOR FREQTRADE ==="
    echo "1) Mostrar status atual"
    echo "2) Monitoramento contínuo"
    echo "3) Fazer backup"
    echo "4) Limpeza de logs"
    echo "5) Análise de performance"
    echo "6) Ver log em tempo real"
    echo "0) Sair"
    echo ""
    read -p "Escolha uma opção: " choice
    
    case $choice in
        1)
            show_status
            ;;
        2)
            monitor_continuous
            ;;
        3)
            backup_data
            ;;
        4)
            cleanup_logs
            ;;
        5)
            check_performance
            ;;
        6)
            if [ -f "$LOG_FILE" ]; then
                log "Monitorando log em tempo real (Ctrl+C para parar)..."
                tail -f "$LOG_FILE"
            else
                error "Log file não encontrado: $LOG_FILE"
            fi
            ;;
        0)
            log "Saindo..."
            exit 0
            ;;
        *)
            warning "Opção inválida"
            ;;
    esac
}

# Verificar se argumentos foram passados
if [ $# -eq 0 ]; then
    # Modo interativo
    while true; do
        show_menu
        echo ""
        read -p "Pressione Enter para continuar..."
    done
else
    # Modo comando
    case $1 in
        status)
            show_status
            ;;
        monitor)
            monitor_continuous
            ;;
        backup)
            backup_data
            ;;
        cleanup)
            cleanup_logs
            ;;
        performance)
            check_performance
            ;;
        log)
            if [ -f "$LOG_FILE" ]; then
                tail -f "$LOG_FILE"
            else
                error "Log file não encontrado: $LOG_FILE"
            fi
            ;;
        *)
            echo "Uso: $0 [status|monitor|backup|cleanup|performance|log]"
            exit 1
            ;;
    esac
fi