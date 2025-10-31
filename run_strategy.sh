#!/bin/bash
# Script to configure and run FreqTrade strategies
# Usage: ./run_strategy.sh [ema|bb] [dry|live]

set -e

# Configuration
FREQTRADE_DIR="/home/marcos/projects/cryptotrader/freqtrade"
USER_DATA_DIR="/home/marcos/projects/cryptotrader/user_data"
PROJECT_DIR="/home/marcos/projects/cryptotrader"
VENV_PATH="$FREQTRADE_DIR/.venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for colored logging
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

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 [ema|bb] [dry|live]"
    echo ""
    echo "Available strategies:"
    echo "  ema  - EMA Crossover Scalping (1m timeframe)"
    echo "  bb   - Bollinger Squeeze Scalping (5m timeframe)"
    echo ""
    echo "Modes:"
    echo "  dry  - Simulation mode (recommended)"
    echo "  live - Real trading (be careful!)"
    exit 1
fi

STRATEGY_TYPE=$1
MODE=$2

# Validate arguments
case $STRATEGY_TYPE in
    ema|bb)
        ;;
    *)
        error "Invalid strategy. Use 'ema' or 'bb'"
        ;;
esac

case $MODE in
    dry|live)
        ;;
    *)
        error "Invalid mode. Use 'dry' or 'live'"
        ;;
esac

# Configure variables based on strategy
if [ "$STRATEGY_TYPE" = "ema" ]; then
    CONFIG_FILE="$PROJECT_DIR/user_data/config/ema_scalping_config.json"
    STRATEGY_NAME="EMAScalpingStrategy"
    STRATEGY_DESC="EMA Crossover Scalping (1m)"
elif [ "$STRATEGY_TYPE" = "bb" ]; then
    CONFIG_FILE="$PROJECT_DIR/user_data/config/bollinger_squeeze_config.json"
    STRATEGY_NAME="BollingerSqueezeScalpStrategy"
    STRATEGY_DESC="Bollinger Squeeze Scalping (5m)"
else
    error "Invalid strategy. Use 'ema' or 'bb'"
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "$VENV_PATH" ]; then
    error "Virtual environment not found at $VENV_PATH"
fi

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error "Configuration file not found: $CONFIG_FILE"
fi

# Activate virtual environment
log "Activating virtual environment..."
source "$VENV_PATH/bin/activate"

# Check if FreqTrade is installed
if ! command -v freqtrade &> /dev/null; then
    error "FreqTrade not found. Make sure it's installed in the virtual environment."
fi

# Check environment variables
if [ -z "$FREQTRADE_API_KEY" ] || [ -z "$FREQTRADE_API_SECRET" ]; then
    warning "API keys not found in environment variables"
    warning "Make sure to configure FREQTRADE_API_KEY and FREQTRADE_API_SECRET"
fi

# Show execution information
echo ""
log "=== EXECUTION CONFIGURATION ==="
log "Strategy: $STRATEGY_DESC ($STRATEGY_NAME)"
log "Mode: $(echo $MODE | tr '[:lower:]' '[:upper:]')"
log "Config: $(basename $CONFIG_FILE)"
log "================================"
echo ""

# Confirmation for live mode
if [ "$MODE" = "live" ]; then
    warning "WARNING: You are about to execute real money trading!"
    warning "Make sure that:"
    warning "1. You tested the strategy in dry-run mode"
    warning "2. You performed extensive backtesting"
    warning "3. You configured appropriate stop-loss"
    warning "4. You have active monitoring"
    echo ""
    read -p "Are you sure you want to continue? (type 'YES' to confirm): " confirm
    
    if [ "$confirm" != "YES" ]; then
        log "Execution cancelled by user"
        exit 0
    fi
fi

# Build FreqTrade command
FREQTRADE_CMD="freqtrade trade --config $CONFIG_FILE --strategy $STRATEGY_NAME --userdir $PROJECT_DIR/user_data"

if [ "$MODE" = "dry" ]; then
    FREQTRADE_CMD="$FREQTRADE_CMD --dry-run"
fi

# Cleanup function on exit
cleanup() {
    log "Stopping FreqTrade..."
    # Send SIGINT to FreqTrade process if running
    if [ ! -z "$FREQTRADE_PID" ]; then
        kill -INT $FREQTRADE_PID 2>/dev/null || true
        wait $FREQTRADE_PID 2>/dev/null || true
    fi
    log "FreqTrade stopped"
}

# Configure trap for cleanup
trap cleanup EXIT INT TERM

# Execute FreqTrade
log "Starting FreqTrade..."
log "Command: $FREQTRADE_CMD"
echo ""

# Execute in background to capture PID
$FREQTRADE_CMD &
FREQTRADE_PID=$!

# Wait for process to finish
wait $FREQTRADE_PID