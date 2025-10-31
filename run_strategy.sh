#!/bin/bash
# Script to configure and run FreqTrade strategies
# Usage: ./run_strategy.sh [ema|bb] [dry|live|backtest] [options]
# Enhanced with comprehensive backtesting capabilities

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

# Function to validate and normalize timerange
normalize_timerange() {
    local timerange="$1"
    
    # If it's a relative date like "-7d", convert to actual dates
    if [[ "$timerange" =~ ^-([0-9]+)d$ ]]; then
        local days="${BASH_REMATCH[1]}"
        local end_date=$(date +'%Y%m%d')
        local start_date=$(date -d "$days days ago" +'%Y%m%d')
        echo "${start_date}-${end_date}"
    # If it's already in correct format, return as is
    elif [[ "$timerange" =~ ^[0-9]{8}-[0-9]{8}?$ ]]; then
        echo "$timerange"
    # If it's from a date to now
    elif [[ "$timerange" =~ ^[0-9]{8}-$ ]]; then
        echo "$timerange"
    else
        # Default fallback
        echo "-7d"
    fi
}

# Function to show data status
show_data_status() {
    local config_file="$1"
    
    log "📊 Data Status Check"
    log "==================="
    
    # Check if freqtrade is available
    if ! command -v freqtrade &> /dev/null; then
        warning "FreqTrade not found in PATH"
        return 1
    fi
    
    # Show available data
    log "Available historical data:"
    freqtrade list-data --config "$config_file" --userdir "$PROJECT_DIR/user_data" 2>/dev/null || warning "Could not list data"
    
    # Show exchange status
    log ""
    log "Exchange connectivity test:"
    freqtrade test-pairlist --config "$config_file" --userdir "$PROJECT_DIR/user_data" 2>/dev/null || warning "Exchange connectivity issues"
    
    # Show strategy status
    log ""
    log "Available strategies:"
    freqtrade list-strategies --userdir "$PROJECT_DIR/user_data" 2>/dev/null || warning "Could not list strategies"
}
estimate_data_size() {
    local timeframe="$1"
    local timerange="$2"
    local strategy_type="$3"
    
    log "Data requirements estimation:"
    log "  Timeframe: $timeframe"
    log "  Strategy: $strategy_type"
    log "  Range: $timerange"
    
    # Get pair count from config
    local pair_count=$(grep -c "USDT:USDT" "$CONFIG_FILE" 2>/dev/null || echo "8")
    log "  Estimated pairs: $pair_count"
    
    # Rough size estimation
    case $timeframe in
        "1m")
            log "  Estimated size: ~500MB for 30 days (all pairs)"
            ;;
        "5m")
            log "  Estimated size: ~100MB for 30 days (all pairs)"
            ;;
    esac
}

# Check for help or special commands
if [ $# -eq 1 ] && [ "$1" = "help" ]; then
    echo "FreqTrade Strategy Runner - Comprehensive Guide"
    echo "=============================================="
    echo ""
    echo "BASIC USAGE:"
    echo "  $0 [strategy] [mode] [options]"
    echo ""
    echo "STRATEGIES:"
    echo "  ema  - EMA Crossover Scalping (1m timeframe, fast execution)"
    echo "  bb   - Bollinger Squeeze Scalping (5m timeframe, breakout detection)"
    echo ""
    echo "MODES:"
    echo "  dry      - Paper trading simulation (safe testing)"
    echo "  live     - Real money trading (requires API setup)"
    echo "  backtest - Historical performance analysis"
    echo ""
    echo "SPECIAL COMMANDS:"
    echo "  $0 help      - Show this comprehensive help"
    echo "  $0 status    - Show system and data status"
    echo ""
    echo "BACKTESTING EXAMPLES:"
    echo "  $0 ema backtest                     # Quick backtest (last 7 days)"
    echo "  $0 bb backtest -30d                 # Last 30 days"
    echo "  $0 ema backtest 20241001-20241030   # Specific date range"
    echo "  $0 bb backtest 20241001-            # From date to now"
    echo "  $0 ema backtest -14d week           # 2 weeks with weekly breakdown"
    echo "  $0 bb backtest 20241001-20241030 month  # Monthly performance breakdown"
    echo ""
    echo "BREAKDOWN OPTIONS:"
    echo "  none   - Overall results only"
    echo "  day    - Daily performance breakdown"
    echo "  week   - Weekly performance breakdown"
    echo "  month  - Monthly performance breakdown"
    echo ""
    echo "ADVANCED FEATURES:"
    echo "  • Automatic data download and validation"
    echo "  • Comprehensive performance analysis"
    echo "  • Visual plots generation (requires plotly)"
    echo "  • Trade-by-trade breakdown"
    echo "  • Risk metrics and drawdown analysis"
    echo "  • Export to JSON, HTML, and CSV formats"
    echo ""
    echo "OUTPUT FILES:"
    echo "  • Results: user_data/backtest_results/[strategy]_backtest_[timestamp].json"
    echo "  • Plots: user_data/plot/[strategy]_[timestamp]/"
    echo "  • Reports: user_data/backtest_results/[strategy]_backtest_[timestamp].html"
    echo ""
    echo "REQUIREMENTS:"
    echo "  • FreqTrade installed and configured"
    echo "  • Valid API keys in .env file (for live trading)"
    echo "  • Internet connection (for data download)"
    echo "  • Optional: plotly for chart generation (pip install plotly)"
    echo ""
    exit 0
fi

# Check for status command
if [ $# -eq 1 ] && [ "$1" = "status" ]; then
    log "FreqTrade System Status"
    log "======================"
    
    # Check virtual environment
    if [ -f "$FREQTRADE_DIR/.venv/bin/activate" ]; then
        log "✅ Virtual environment found"
        source "$FREQTRADE_DIR/.venv/bin/activate"
    else
        error "❌ Virtual environment not found at $FREQTRADE_DIR/.venv/"
    fi
    
    # Check FreqTrade installation
    if command -v freqtrade &> /dev/null; then
        log "✅ FreqTrade installed: $(freqtrade --version 2>/dev/null || echo 'version unknown')"
    else
        error "❌ FreqTrade not found"
    fi
    
    # Check configurations
    log ""
    log "Configuration files:"
    for config in "ema_scalping_config.json" "bollinger_squeeze_config.json"; do
        if [ -f "$USER_DATA_DIR/config/$config" ]; then
            log "✅ $config"
        else
            warning "❌ $config missing"
        fi
    done
    
    # Check strategies
    log ""
    log "Strategy files:"
    for strategy in "EMAScalpingStrategy.py" "BollingerSqueezeScalpStrategy.py"; do
        if [ -f "$USER_DATA_DIR/strategies/$strategy" ]; then
            log "✅ $strategy"
        else
            warning "❌ $strategy missing"
        fi
    done
    
    # Check environment variables
    log ""
    log "Environment configuration:"
    if [ -n "$FREQTRADE_API_KEY" ]; then
        log "✅ API key configured"
    else
        warning "❌ FREQTRADE_API_KEY not set"
    fi
    
    if [ -n "$FREQTRADE_API_SECRET" ]; then
        log "✅ API secret configured"
    else
        warning "❌ FREQTRADE_API_SECRET not set"
    fi
    
    # Show data status for both strategies
    log ""
    if [ -f "$USER_DATA_DIR/config/ema_scalping_config.json" ]; then
        show_data_status "$USER_DATA_DIR/config/ema_scalping_config.json"
    fi
    
    exit 0
fi

# Check arguments
if [ $# -lt 2 ] || [ $# -gt 4 ]; then
    echo "Usage: $0 [ema|bb] [dry|live|backtest] [options]"
    echo ""
    echo "Available strategies:"
    echo "  ema  - EMA Crossover Scalping (1m timeframe)"
    echo "  bb   - Bollinger Squeeze Scalping (5m timeframe)"
    echo ""
    echo "Modes:"
    echo "  dry      - Simulation mode (recommended)"
    echo "  live     - Real trading (be careful!)"
    echo "  backtest - Historical backtesting"
    echo ""
    echo "Backtest Options:"
    echo "  $0 [ema|bb] backtest [timerange] [breakdown]"
    echo ""
    echo "  timerange examples:"
    echo "    20231001-20241030  - Specific date range"
    echo "    20241001-          - From date to now"
    echo "    -30d               - Last 30 days"
    echo "    -7d                - Last 7 days (default)"
    echo ""
    echo "  breakdown options:"
    echo "    day    - Daily breakdown"
    echo "    week   - Weekly breakdown"
    echo "    month  - Monthly breakdown"
    echo "    none   - No breakdown (default)"
    echo ""
    echo "Examples:"
    echo "  $0 ema dry                           # Dry run EMA strategy"
    echo "  $0 bb backtest                       # Backtest BB strategy (last 7 days)"
    echo "  $0 ema backtest 20241001-20241030    # Backtest EMA (specific range)"
    echo "  $0 bb backtest -30d week             # Backtest BB (30 days, weekly breakdown)"
    echo "  $0 ema backtest 20231001- month      # Backtest EMA (from date, monthly breakdown)"
    exit 1
fi

STRATEGY_TYPE=$1
MODE=$2
TIMERANGE=${3:-"-7d"}  # Default to last 7 days for backtest
BREAKDOWN=${4:-"none"} # Default to no breakdown

# Validate arguments
case $STRATEGY_TYPE in
    ema|bb)
        ;;
    *)
        error "Invalid strategy. Use 'ema' or 'bb'"
        ;;
esac

case $MODE in
    dry|live|backtest)
        ;;
    *)
        error "Invalid mode. Use 'dry', 'live', or 'backtest'"
        ;;
esac

# Validate breakdown option for backtest
if [ "$MODE" = "backtest" ]; then
    case $BREAKDOWN in
        day|week|month|none)
            ;;
        *)
            error "Invalid breakdown option. Use 'day', 'week', 'month', or 'none'"
            ;;
    esac
fi

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
if [ "$MODE" = "backtest" ]; then
    log "Timerange: $TIMERANGE"
    log "Breakdown: $BREAKDOWN"
fi
log "================================"
echo ""

# Handle backtest mode
if [ "$MODE" = "backtest" ]; then
    log "Starting comprehensive backtesting process..."
    
    # Normalize timerange
    NORMALIZED_TIMERANGE=$(normalize_timerange "$TIMERANGE")
    log "Using timerange: $NORMALIZED_TIMERANGE"
    
    # Create backtest results directory
    BACKTEST_DIR="$PROJECT_DIR/user_data/backtest_results"
    mkdir -p "$BACKTEST_DIR"
    
    # Generate timestamp for result files
    TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
    RESULT_FILE="$BACKTEST_DIR/${STRATEGY_TYPE}_backtest_${TIMESTAMP}"
    
    # Get timeframe from strategy
    if [ "$STRATEGY_TYPE" = "ema" ]; then
        TIMEFRAME="1m"
    else
        TIMEFRAME="5m"
    fi
    
    # Show data estimation
    estimate_data_size "$TIMEFRAME" "$NORMALIZED_TIMERANGE" "$STRATEGY_TYPE"
    
    # Ask for confirmation for large downloads
    if [[ "$NORMALIZED_TIMERANGE" =~ ^[0-9]{8}-[0-9]{8}$ ]]; then
        local start_date="${NORMALIZED_TIMERANGE%-*}"
        local end_date="${NORMALIZED_TIMERANGE#*-}"
        local start_epoch=$(date -d "${start_date:0:4}-${start_date:4:2}-${start_date:6:2}" +%s)
        local end_epoch=$(date -d "${end_date:0:4}-${end_date:4:2}-${end_date:6:2}" +%s)
        local days=$(( (end_epoch - start_epoch) / 86400 ))
        
        if [ $days -gt 30 ]; then
            warning "You're about to download data for $days days, which may take significant time and space."
            read -p "Continue? (y/N): " confirm_download
            if [[ ! "$confirm_download" =~ ^[Yy]$ ]]; then
                log "Backtesting cancelled by user"
                exit 0
            fi
        fi
    fi
    
    # Download data
    log "Downloading/updating market data for $TIMEFRAME timeframe..."
    DATA_CMD="freqtrade download-data --config $CONFIG_FILE --timeframe $TIMEFRAME"
    
    # Add timerange to download command
    if [[ "$NORMALIZED_TIMERANGE" =~ ^-[0-9]+d$ ]]; then
        DAYS=${NORMALIZED_TIMERANGE#-}
        DAYS=${DAYS%d}
        DATA_CMD="$DATA_CMD --days $DAYS"
    else
        DATA_CMD="$DATA_CMD --timerange $NORMALIZED_TIMERANGE"
    fi
    
    # Add additional timeframes for better analysis
    DATA_CMD="$DATA_CMD --timeframes $TIMEFRAME 1h 1d"
    
    log "Executing: $DATA_CMD"
    if ! $DATA_CMD; then
        error "Failed to download market data"
    fi
    
    # Build comprehensive backtest command
    BACKTEST_CMD="freqtrade backtesting"
    BACKTEST_CMD="$BACKTEST_CMD --config $CONFIG_FILE"
    BACKTEST_CMD="$BACKTEST_CMD --strategy $STRATEGY_NAME"
    BACKTEST_CMD="$BACKTEST_CMD --userdir $PROJECT_DIR/user_data"
    BACKTEST_CMD="$BACKTEST_CMD --timerange $NORMALIZED_TIMERANGE"
    BACKTEST_CMD="$BACKTEST_CMD --export trades,signals"
    BACKTEST_CMD="$BACKTEST_CMD --export-filename $RESULT_FILE"
    BACKTEST_CMD="$BACKTEST_CMD --enable-position-stacking"
    BACKTEST_CMD="$BACKTEST_CMD --disable-max-market-positions"
    BACKTEST_CMD="$BACKTEST_CMD --cache none"  # Always fresh analysis
    
    # Add breakdown if specified
    if [ "$BREAKDOWN" != "none" ]; then
        BACKTEST_CMD="$BACKTEST_CMD --breakdown $BREAKDOWN"
    fi
    
    # Execute backtest
    log "Starting backtest with command:"
    log "$BACKTEST_CMD"
    echo ""
    
    if $BACKTEST_CMD; then
        log "✅ Backtest completed successfully!"
        echo ""
        
        # Generate comprehensive analysis
        log "=== GENERATING COMPREHENSIVE ANALYSIS ==="
        
        # 1. Basic backtest analysis
        log "📊 Running backtest analysis..."
        freqtrade backtesting-analysis \
            --config "$CONFIG_FILE" \
            --analysis-groups "0,1,2,3,4,5" \
            --userdir "$PROJECT_DIR/user_data" 2>/dev/null || warning "Basic analysis failed"
        
        # 2. Generate plots
        log "📈 Generating performance plots..."
        PLOT_DIR="$PROJECT_DIR/user_data/plot"
        mkdir -p "$PLOT_DIR"
        
        freqtrade plot-dataframe \
            --config "$CONFIG_FILE" \
            --strategy "$STRATEGY_NAME" \
            --userdir "$PROJECT_DIR/user_data" \
            --timerange "$NORMALIZED_TIMERANGE" \
            --plot-limit 1000 \
            --export-path "$PLOT_DIR/${STRATEGY_TYPE}_${TIMESTAMP}" \
            --indicators1 ema_fast,ema_medium,ema_slow \
            --indicators2 rsi,macd 2>/dev/null || warning "Plot generation failed (install plotly: pip install plotly)"
        
        # 3. Profit plots
        log "💰 Generating profit plots..."
        freqtrade plot-profit \
            --config "$CONFIG_FILE" \
            --userdir "$PROJECT_DIR/user_data" \
            --export-path "$PLOT_DIR/${STRATEGY_TYPE}_${TIMESTAMP}" \
            --timerange "$NORMALIZED_TIMERANGE" 2>/dev/null || warning "Profit plot generation failed"
        
        # 4. Show recent trades
        log "🔍 Recent trades analysis:"
        freqtrade show_trades \
            --config "$CONFIG_FILE" \
            --userdir "$PROJECT_DIR/user_data" \
            --timerange "$NORMALIZED_TIMERANGE" \
            --print-json | tail -10 2>/dev/null || warning "Trade analysis failed"
        
        # 5. Performance by pair
        log "📋 Performance by trading pair:"
        freqtrade show_trades \
            --config "$CONFIG_FILE" \
            --userdir "$PROJECT_DIR/user_data" \
            --timerange "$NORMALIZED_TIMERANGE" \
            --print-json 2>/dev/null | \
            jq -r 'group_by(.pair) | .[] | {pair: .[0].pair, count: length, total_profit: ([.[] | .profit_abs] | add)}' 2>/dev/null || \
            warning "Pair analysis failed (install jq for detailed analysis)"
        
        # 6. Generate HTML report
        log "📄 Generating HTML report..."
        freqtrade hyperopt-show \
            --config "$CONFIG_FILE" \
            --userdir "$PROJECT_DIR/user_data" \
            --print-json 2>/dev/null > "$RESULT_FILE.html" || warning "HTML report generation failed"
        
        # Show result locations
        echo ""
        log "=== RESULTS SUMMARY ==="
        log "📁 Results directory: $BACKTEST_DIR"
        log "📊 Raw results: ${RESULT_FILE}.json"
        log "📈 Plots directory: $PLOT_DIR/${STRATEGY_TYPE}_${TIMESTAMP}/"
        log "📄 HTML report: ${RESULT_FILE}.html"
        
        # Quick performance summary
        echo ""
        log "=== QUICK PERFORMANCE SUMMARY ==="
        if [ -f "${RESULT_FILE}-backtest-result.json" ]; then
            python3 -c "
import json
try:
    with open('${RESULT_FILE}-backtest-result.json', 'r') as f:
        data = json.load(f)
    strategy_stats = data.get('strategy', {}).get('$STRATEGY_NAME', {})
    
    print('📈 Total Trades:', strategy_stats.get('total_trades', 'N/A'))
    print('💰 Total Profit:', f\"{strategy_stats.get('profit_total_abs', 0):.2f} USDT\")
    print('📊 Profit %:', f\"{strategy_stats.get('profit_total', 0)*100:.2f}%\")
    print('🎯 Win Rate:', f\"{strategy_stats.get('wins', 0)/max(strategy_stats.get('total_trades', 1), 1)*100:.1f}%\")
    print('📉 Max Drawdown:', f\"{strategy_stats.get('max_drawdown', 0)*100:.2f}%\")
    print('⏱️  Avg Trade Duration:', strategy_stats.get('trade_count_long', 'N/A'))
except Exception as e:
    print('⚠️  Could not parse results:', str(e))
" 2>/dev/null || warning "Could not generate performance summary"
        fi
        
        echo ""
        log "🎯 Backtest analysis complete! Check the results above."
        
    else
        error "❌ Backtest failed!"
    fi
    
    exit 0
fi

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