#!/bin/bash
# Script para configurar e executar estratégias FreqTrade
# Uso: ./run_strategy.sh [rsi|macd] [dry|live]

set -e

# Configurações
FREQTRADE_DIR="/home/marcos/projects/cryptotrader/freqtrade"
USER_DATA_DIR="/home/marcos/projects/cryptotrader/user_data"
PROJECT_DIR="/home/marcos/projects/cryptotrader"
VENV_PATH="$FREQTRADE_DIR/.venv"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Verificar argumentos
if [ $# -ne 2 ]; then
    echo "Uso: $0 [ema|bb] [dry|live]"
    echo ""
    echo "Estratégias disponíveis:"
    echo "  ema  - EMA Crossover Scalping (1m timeframe)"
    echo "  bb   - Bollinger Squeeze Scalping (5m timeframe)"
    echo ""
    echo "Modos:"
    echo "  dry  - Modo simulação (recomendado)"
    echo "  live - Trading real (cuidado!)"
    exit 1
fi

STRATEGY_TYPE=$1
MODE=$2

# Validar argumentos
case $STRATEGY_TYPE in
    ema|bb)
        ;;
    *)
        error "Estratégia inválida. Use 'ema' ou 'bb'"
        ;;
esac

case $MODE in
    dry|live)
        ;;
    *)
        error "Modo inválido. Use 'dry' ou 'live'"
        ;;
esac

# Configurar variáveis baseadas na estratégia
if [ "$STRATEGY_TYPE" = "ema" ]; then
    CONFIG_FILE="$PROJECT_DIR/user_data/config/ema_scalping_config.json"
    STRATEGY_NAME="EMAScalpingStrategy"
    STRATEGY_DESC="EMA Crossover Scalping (1m)"
elif [ "$STRATEGY_TYPE" = "bb" ]; then
    CONFIG_FILE="$PROJECT_DIR/user_data/config/bollinger_squeeze_config.json"
    STRATEGY_NAME="BollingerSqueezeScalpStrategy"
    STRATEGY_DESC="Bollinger Squeeze Scalping (5m)"
else
    error "Estratégia inválida. Use 'ema' ou 'bb'"
    exit 1
fi

# Verificar se ambiente virtual existe
if [ ! -d "$VENV_PATH" ]; then
    error "Ambiente virtual não encontrado em $VENV_PATH"
fi

# Verificar se arquivo de configuração existe
if [ ! -f "$CONFIG_FILE" ]; then
    error "Arquivo de configuração não encontrado: $CONFIG_FILE"
fi

# Ativar ambiente virtual
log "Ativando ambiente virtual..."
source "$VENV_PATH/bin/activate"

# Verificar se FreqTrade está instalado
if ! command -v freqtrade &> /dev/null; then
    error "FreqTrade não encontrado. Certifique-se de que está instalado no ambiente virtual."
fi

# Verificar variáveis de ambiente
if [ -z "$FREQTRADE_API_KEY" ] || [ -z "$FREQTRADE_API_SECRET" ]; then
    warning "API keys não encontradas nas variáveis de ambiente"
    warning "Certifique-se de configurar FREQTRADE_API_KEY e FREQTRADE_API_SECRET"
fi

# Mostrar informações da execução
echo ""
log "=== CONFIGURAÇÃO DA EXECUÇÃO ==="
log "Estratégia: $STRATEGY_DESC ($STRATEGY_NAME)"
log "Modo: $(echo $MODE | tr '[:lower:]' '[:upper:]')"
log "Config: $(basename $CONFIG_FILE)"
log "=================================="
echo ""

# Confirmação para modo live
if [ "$MODE" = "live" ]; then
    warning "ATENÇÃO: Você está prestes a executar trading com dinheiro real!"
    warning "Certifique-se de que:"
    warning "1. Testou a estratégia em modo dry-run"
    warning "2. Fez backtest extensivo"
    warning "3. Configurou stop-loss apropriado"
    warning "4. Tem monitoramento ativo"
    echo ""
    read -p "Tem certeza que deseja continuar? (digite 'SIM' para confirmar): " confirm
    
    if [ "$confirm" != "SIM" ]; then
        log "Execução cancelada pelo usuário"
        exit 0
    fi
fi

# Construir comando FreqTrade
FREQTRADE_CMD="freqtrade trade --config $CONFIG_FILE --strategy $STRATEGY_NAME --userdir $PROJECT_DIR/user_data"

if [ "$MODE" = "dry" ]; then
    FREQTRADE_CMD="$FREQTRADE_CMD --dry-run"
fi

# Função para cleanup ao sair
cleanup() {
    log "Parando FreqTrade..."
    # Enviar SIGINT para processo FreqTrade se estiver rodando
    if [ ! -z "$FREQTRADE_PID" ]; then
        kill -INT $FREQTRADE_PID 2>/dev/null || true
        wait $FREQTRADE_PID 2>/dev/null || true
    fi
    log "FreqTrade parado"
}

# Configurar trap para cleanup
trap cleanup EXIT INT TERM

# Executar FreqTrade
log "Iniciando FreqTrade..."
log "Comando: $FREQTRADE_CMD"
echo ""

# Executar em background para capturar PID
$FREQTRADE_CMD &
FREQTRADE_PID=$!

# Esperar processo terminar
wait $FREQTRADE_PID