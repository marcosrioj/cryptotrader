#!/bin/bash
# Script de configuração automática do ambiente CryptoTrader
# Este script configura todos os caminhos para usar /home/marcos/projects/cryptotrader

set -e

# Configurações
BASE_DIR="/home/marcos/projects/cryptotrader"
FREQTRADE_DIR="$BASE_DIR/freqtrade"
USER_DATA_DIR="$BASE_DIR/user_data"

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

# Verificar se estamos no diretório correto
if [ "$(pwd)" != "$BASE_DIR" ]; then
    error "Execute este script a partir do diretório: $BASE_DIR"
    exit 1
fi

log "Iniciando configuração do ambiente CryptoTrader..."

# Verificar se FreqTrade está instalado
if [ ! -d "$FREQTRADE_DIR" ]; then
    warning "FreqTrade não encontrado em $FREQTRADE_DIR"
    warning "Execute primeiro o guia de instalação do FreqTrade"
    exit 1
fi

# Verificar ambiente virtual
if [ ! -f "$FREQTRADE_DIR/.venv/bin/activate" ]; then
    error "Ambiente virtual não encontrado em $FREQTRADE_DIR/.venv/"
    exit 1
fi

# Ativar ambiente virtual
log "Ativando ambiente virtual..."
source "$FREQTRADE_DIR/.venv/bin/activate"

# Verificar se FreqTrade está funcionando
if ! command -v freqtrade &> /dev/null; then
    error "FreqTrade não está disponível no ambiente virtual"
    exit 1
fi

# Criar diretórios necessários
log "Criando estrutura de diretórios..."
mkdir -p "$USER_DATA_DIR"/{logs,data,backtest_results,hyperopt_results,plot}
mkdir -p "$BASE_DIR/backups"

# Verificar arquivos de configuração
log "Verificando arquivos de configuração..."
if [ ! -f "$USER_DATA_DIR/config/config.json" ]; then
    warning "Arquivo config.json não encontrado"
fi

if [ ! -f "$USER_DATA_DIR/config/rsi_bb_config.json" ]; then
    warning "Arquivo rsi_bb_config.json não encontrado"
fi

if [ ! -f "$USER_DATA_DIR/config/macd_ema_config.json" ]; then
    warning "Arquivo macd_ema_config.json não encontrado"
fi

# Verificar estratégias
log "Verificando estratégias..."
if [ ! -f "$USER_DATA_DIR/strategies/RSIBBStrategy.py" ]; then
    warning "Estratégia RSIBBStrategy.py não encontrada"
fi

if [ ! -f "$USER_DATA_DIR/strategies/MACDEMAStrategy.py" ]; then
    warning "Estratégia MACDEMAStrategy.py não encontrada"
fi

# Verificar arquivo .env
if [ ! -f "$BASE_DIR/.env" ]; then
    warning "Arquivo .env não encontrado"
    if [ -f "$BASE_DIR/.env.example" ]; then
        info "Copiando .env.example para .env"
        cp "$BASE_DIR/.env.example" "$BASE_DIR/.env"
        warning "Configure suas credenciais no arquivo .env"
    fi
else
    log "Arquivo .env encontrado"
fi

# Testar estratégias
log "Testando estratégias..."
if freqtrade list-strategies --userdir "$USER_DATA_DIR" | grep -q "RSIBBStrategy"; then
    log "✅ RSIBBStrategy detectada"
else
    error "❌ RSIBBStrategy não detectada"
fi

if freqtrade list-strategies --userdir "$USER_DATA_DIR" | grep -q "MACDEMAStrategy"; then
    log "✅ MACDEMAStrategy detectada"
else
    error "❌ MACDEMAStrategy não detectada"
fi

# Testar configurações
log "Testando configurações..."
for config in "rsi_bb_config.json" "macd_ema_config.json"; do
    if [ -f "$USER_DATA_DIR/config/$config" ]; then
        if freqtrade show-config --config "$USER_DATA_DIR/config/$config" --userdir "$USER_DATA_DIR" > /dev/null 2>&1; then
            log "✅ $config válida"
        else
            error "❌ $config inválida"
        fi
    fi
done

# Verificar permissões dos scripts
log "Verificando permissões dos scripts..."
for script in "run_strategy.sh" "monitor.sh"; do
    if [ -f "$BASE_DIR/$script" ]; then
        if [ -x "$BASE_DIR/$script" ]; then
            log "✅ $script executável"
        else
            warning "Tornando $script executável..."
            chmod +x "$BASE_DIR/$script"
        fi
    else
        error "❌ Script $script não encontrado"
    fi
done

# Mostrar informações do ambiente
info "=== INFORMAÇÕES DO AMBIENTE ==="
info "Diretório base: $BASE_DIR"
info "FreqTrade: $FREQTRADE_DIR"
info "User data: $USER_DATA_DIR"
info "Versão FreqTrade: $(freqtrade --version 2>/dev/null || echo 'Erro ao obter versão')"
info "Estratégias disponíveis:"
freqtrade list-strategies --userdir "$USER_DATA_DIR" 2>/dev/null | grep -E "(RSIBBStrategy|MACDEMAStrategy)" || echo "Nenhuma estratégia encontrada"

echo ""
log "=== PRÓXIMOS PASSOS ==="
log "1. Configure suas credenciais no arquivo .env"
log "2. Execute: source .env"
log "3. Teste em dry-run: ./run_strategy.sh rsi dry"
log "4. Monitore: ./monitor.sh status"

echo ""
log "Configuração do ambiente concluída!"

# Criar alias úteis
cat > "$BASE_DIR/aliases.sh" << 'EOF'
#!/bin/bash
# Aliases úteis para CryptoTrader

# Ativar ambiente
alias ft-env='source /home/marcos/projects/cryptotrader/freqtrade/.venv/bin/activate && source /home/marcos/projects/cryptotrader/.env'

# Scripts principais
alias ft-rsi-dry='/home/marcos/projects/cryptotrader/run_strategy.sh rsi dry'
alias ft-macd-dry='/home/marcos/projects/cryptotrader/run_strategy.sh macd dry'
alias ft-rsi-live='/home/marcos/projects/cryptotrader/run_strategy.sh rsi live'
alias ft-macd-live='/home/marcos/projects/cryptotrader/run_strategy.sh macd live'

# Monitoramento
alias ft-status='/home/marcos/projects/cryptotrader/monitor.sh status'
alias ft-monitor='/home/marcos/projects/cryptotrader/monitor.sh monitor'
alias ft-backup='/home/marcos/projects/cryptotrader/monitor.sh backup'

# Logs
alias ft-log='tail -f /home/marcos/projects/cryptotrader/user_data/logs/freqtrade.log'

# Navegação
alias ft-cd='cd /home/marcos/projects/cryptotrader'

echo "Aliases carregados! Use ft-env para ativar o ambiente completo"
EOF

chmod +x "$BASE_DIR/aliases.sh"
log "Aliases criados em aliases.sh - Execute: source aliases.sh"