#!/bin/bash
# Backup and monitoring script for FreqTrade
# Usage: ./monitor.sh

set -e

# Configuration
USER_DATA_DIR="/home/marcos/projects/cryptotrader/user_data"
PROJECT_DIR="/home/marcos/projects/cryptotrader"
BACKUP_DIR="/home/marcos/projects/cryptotrader/backups"
LOG_FILE="$USER_DATA_DIR/logs/freqtrade.log"

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

# Function to backup data
backup_data() {
    log "Starting backup..."
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR/$(date +'%Y-%m')"
    
    BACKUP_FILE="$BACKUP_DIR/$(date +'%Y-%m')/backup_$(date +'%Y%m%d_%H%M%S').tar.gz"
    
    # Backup important data
    tar -czf "$BACKUP_FILE" \
        -C "$USER_DATA_DIR" \
        --exclude="logs/*.log*" \
        --exclude="data/*.json" \
        . 2>/dev/null || warning "Some files may not have been included in the backup"
    
    log "Backup created: $BACKUP_FILE"
    
    # Clean old backups (keep only last 30 days)
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    log "Old backups removed"
}

# Function to show status
show_status() {
    info "=== FREQTRADE STATUS ==="
    
    # Check if FreqTrade is running
    if pgrep -f "freqtrade trade" > /dev/null; then
        log "✅ FreqTrade is running"
        
        # Show process information
        info "FreqTrade processes:"
        pgrep -f "freqtrade trade" | xargs ps -p | tail -n +2
        
    else
        warning "❌ FreqTrade is not running"
    fi
    
    echo ""
    
    # Check disk space
    info "=== DISK SPACE ==="
    df -h "$USER_DATA_DIR" | tail -n 1 | awk '{print "Used: " $3 " / " $2 " (" $5 ")"}'
    
    echo ""
    
    # Check recent logs
    if [ -f "$LOG_FILE" ]; then
        info "=== LATEST LOG ENTRIES ==="
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
        warning "Log file not found: $LOG_FILE"
    fi
    
    echo ""
    
    # Check recent trades (if database exists)
    DB_FILE="$USER_DATA_DIR/tradesv3.sqlite"
    if [ -f "$DB_FILE" ]; then
        info "=== RECENT TRADES ==="
        # Use FreqTrade to show trades (requires active environment)
        if command -v freqtrade &> /dev/null; then
            freqtrade show_trades --db-url "sqlite:///$DB_FILE" --days 1 2>/dev/null | tail -n 10 || warning "Could not access trade data"
        else
            warning "FreqTrade is not in current PATH"
        fi
    fi
}

# Function for continuous monitoring
monitor_continuous() {
    log "Starting continuous monitoring (Ctrl+C to stop)..."
    
    while true; do
        clear
        show_status
        
        info "Next update in 30 seconds..."
        sleep 30
    done
}

# Function for log cleanup
cleanup_logs() {
    log "Starting log cleanup..."
    
    # Compress old logs
    find "$USER_DATA_DIR/logs" -name "*.log" -mtime +7 -exec gzip {} \;
    
    # Remove very old logs
    find "$USER_DATA_DIR/logs" -name "*.log.gz" -mtime +30 -delete
    
    log "Log cleanup completed"
}

# Function to check performance
check_performance() {
    info "=== PERFORMANCE ANALYSIS ==="
    
    DB_FILE="$USER_DATA_DIR/tradesv3.sqlite"
    if [ -f "$DB_FILE" ] && command -v freqtrade &> /dev/null; then
        
        # Performance for last 7 days
        info "Performance last 7 days:"
        freqtrade show_trades --db-url "sqlite:///$DB_FILE" --days 7 2>/dev/null || warning "Error accessing data"
        
        echo ""
        
        # Performance per pair
        info "Performance per pair (last 30 days):"
        freqtrade show_trades --db-url "sqlite:///$DB_FILE" --days 30 --print-json 2>/dev/null | \
        jq -r '.[] | "\(.pair): \(.profit_ratio * 100 | round)%"' 2>/dev/null | \
        sort | uniq -c | sort -nr || warning "jq not available for detailed analysis"
        
    else
        warning "Trade database not found or FreqTrade not available"
    fi
}

# Main menu
show_menu() {
    echo ""
    info "=== FREQTRADE MONITOR ==="
    echo "1) Show current status"
    echo "2) Continuous monitoring"
    echo "3) Create backup"
    echo "4) Log cleanup"
    echo "5) Performance analysis"
    echo "6) View real-time log"
    echo "0) Exit"
    echo ""
    read -p "Choose an option: " choice
    
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
                log "Monitoring real-time log (Ctrl+C to stop)..."
                tail -f "$LOG_FILE"
            else
                error "Log file not found: $LOG_FILE"
            fi
            ;;
        0)
            log "Exiting..."
            exit 0
            ;;
        *)
            warning "Invalid option"
            ;;
    esac
}

# Check if arguments were passed
if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        echo ""
        read -p "Press Enter to continue..."
    done
else
    # Command mode
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
                error "Log file not found: $LOG_FILE"
            fi
            ;;
        *)
            echo "Usage: $0 [status|monitor|backup|cleanup|performance|log]"
            exit 1
            ;;
    esac
fi