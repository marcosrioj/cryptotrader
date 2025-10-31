#!/bin/bash
# CryptoTrader automatic environment setup script
# This script configures all paths to use /home/marcos/projects/cryptotrader

set -e

# Configuration
BASE_DIR="/home/marcos/projects/cryptotrader"
FREQTRADE_DIR="$BASE_DIR/freqtrade"
USER_DATA_DIR="$BASE_DIR/user_data"

# Colors
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

# Check if we're in the correct directory
if [ "$(pwd)" != "$BASE_DIR" ]; then
    error "Run this script from the directory: $BASE_DIR"
    exit 1
fi

log "Starting CryptoTrader environment setup..."

# Check if FreqTrade is installed
if [ ! -d "$FREQTRADE_DIR" ]; then
    warning "FreqTrade not found at $FREQTRADE_DIR"
    warning "Run the FreqTrade installation guide first"
    exit 1
fi

# Check virtual environment
if [ ! -f "$FREQTRADE_DIR/.venv/bin/activate" ]; then
    error "Virtual environment not found at $FREQTRADE_DIR/.venv/"
    exit 1
fi

# Activate virtual environment
log "Activating virtual environment..."
source "$FREQTRADE_DIR/.venv/bin/activate"

# Check if FreqTrade is working
if ! command -v freqtrade &> /dev/null; then
    error "FreqTrade is not available in the virtual environment"
    exit 1
fi

# Create necessary directories
log "Creating directory structure..."
mkdir -p "$USER_DATA_DIR"/{logs,data,backtest_results,hyperopt_results,plot}
mkdir -p "$BASE_DIR/backups"

# Check configuration files
log "Checking configuration files..."
if [ ! -f "$USER_DATA_DIR/config/config.json" ]; then
    warning "config.json file not found"
fi

if [ ! -f "$USER_DATA_DIR/config/ema_scalping_config.json" ]; then
    warning "ema_scalping_config.json file not found"
fi

if [ ! -f "$USER_DATA_DIR/config/bollinger_squeeze_config.json" ]; then
    warning "bollinger_squeeze_config.json file not found"
fi

# Check strategies
log "Checking strategies..."
if [ ! -f "$USER_DATA_DIR/strategies/EMAScalpingStrategy.py" ]; then
    warning "EMAScalpingStrategy.py strategy not found"
fi

if [ ! -f "$USER_DATA_DIR/strategies/BollingerSqueezeScalpStrategy.py" ]; then
    warning "BollingerSqueezeScalpStrategy.py strategy not found"
fi

# Check .env file
if [ ! -f "$BASE_DIR/.env" ]; then
    warning ".env file not found"
    if [ -f "$BASE_DIR/.env.example" ]; then
        info "Copying .env.example to .env"
        cp "$BASE_DIR/.env.example" "$BASE_DIR/.env"
        warning "Configure your credentials in the .env file"
    fi
else
    log ".env file found"
fi

# Test strategies
log "Testing strategies..."
if freqtrade list-strategies --userdir "$USER_DATA_DIR" | grep -q "EMAScalpingStrategy"; then
    log "✅ EMAScalpingStrategy detected"
else
    error "❌ EMAScalpingStrategy not detected"
fi

if freqtrade list-strategies --userdir "$USER_DATA_DIR" | grep -q "BollingerSqueezeScalpStrategy"; then
    log "✅ BollingerSqueezeScalpStrategy detected"
else
    error "❌ BollingerSqueezeScalpStrategy not detected"
fi

# Test configurations
log "Testing configurations..."
for config in "ema_scalping_config.json" "bollinger_squeeze_config.json"; do
    if [ -f "$USER_DATA_DIR/config/$config" ]; then
        if freqtrade show-config --config "$USER_DATA_DIR/config/$config" --userdir "$USER_DATA_DIR" > /dev/null 2>&1; then
            log "✅ $config valid"
        else
            error "❌ $config invalid"
        fi
    fi
done

# Check script permissions
log "Checking script permissions..."
for script in "run_strategy.sh" "monitor.sh"; do
    if [ -f "$BASE_DIR/$script" ]; then
        if [ -x "$BASE_DIR/$script" ]; then
            log "✅ $script executable"
        else
            warning "Making $script executable..."
            chmod +x "$BASE_DIR/$script"
        fi
    else
        error "❌ Script $script not found"
    fi
done

# Show environment information
info "=== ENVIRONMENT INFORMATION ==="
info "Base directory: $BASE_DIR"
info "FreqTrade: $FREQTRADE_DIR"
info "User data: $USER_DATA_DIR"
info "FreqTrade version: $(freqtrade --version 2>/dev/null || echo 'Error getting version')"
info "Available strategies:"
freqtrade list-strategies --userdir "$USER_DATA_DIR" 2>/dev/null | grep -E "(EMAScalpingStrategy|BollingerSqueezeScalpStrategy)" || echo "No strategies found"

echo ""
log "=== NEXT STEPS ==="
log "1. Configure your credentials in the .env file"
log "2. Run: source .env"
log "3. Test in dry-run: ./run_strategy.sh ema dry"
log "4. Monitor: ./monitor.sh status"

echo ""
log "Environment setup completed!"

# Create useful aliases
cat > "$BASE_DIR/aliases.sh" << 'EOF'
#!/bin/bash
# Useful aliases for CryptoTrader

# Activate environment
alias ft-env='source /home/marcos/projects/cryptotrader/freqtrade/.venv/bin/activate && source /home/marcos/projects/cryptotrader/.env'

# Main scripts
alias ft-ema-dry='/home/marcos/projects/cryptotrader/run_strategy.sh ema dry'
alias ft-bb-dry='/home/marcos/projects/cryptotrader/run_strategy.sh bb dry'
alias ft-ema-live='/home/marcos/projects/cryptotrader/run_strategy.sh ema live'
alias ft-bb-live='/home/marcos/projects/cryptotrader/run_strategy.sh bb live'

# Monitoring
alias ft-status='/home/marcos/projects/cryptotrader/monitor.sh status'
alias ft-monitor='/home/marcos/projects/cryptotrader/monitor.sh monitor'
alias ft-backup='/home/marcos/projects/cryptotrader/monitor.sh backup'

# Logs
alias ft-log='tail -f /home/marcos/projects/cryptotrader/user_data/logs/freqtrade.log'

# Navigation
alias ft-cd='cd /home/marcos/projects/cryptotrader'

echo "Aliases loaded! Use ft-env to activate the complete environment"
EOF

chmod +x "$BASE_DIR/aliases.sh"
log "Aliases created in aliases.sh - Run: source aliases.sh"