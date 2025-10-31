# CryptoTrader - FreqTrade Scalping Strategies

This repository contains automated cryptocurrency trading strategies using FreqTrade, focused on high-frequency scalping strategies optimized for altcoin futures trading.

## 📋 Table of Contents

- [Installation](#installation)
- [Available Strategies](#available-strategies)
- [Configuration](#configuration)
- [How to Use](#how-to-use)
- [Backtesting](#backtesting)
- [Optimization](#optimization)
- [Monitoring](#monitoring)
- [Security](#security)

## 🚀 Installation

Follow the complete installation guide in [FREQTRADE_INSTALLATION_GUIDE.md](./FREQTRADE_INSTALLATION_GUIDE.md)

### Quick Installation

```bash
# Clone the repository
git clone https://github.com/marcosrioj/cryptotrader.git
cd cryptotrader

# Follow the FreqTrade installation guide steps
# Strategies and configurations are already organized in user_data/

# Automatic environment setup
./setup_environment.sh
```

## 📊 Available Strategies

**Configured Exchange**: Bybit Perpetual Futures (Swap)
**Pair Format**: `SYMBOL/USDT:USDT` (e.g., `BTC/USDT:USDT`)
**Trading Mode**: Futures with isolated margin

### 1. EMA Crossover Scalping Strategy (`EMAScalpingStrategy`)

**Description**: High-frequency scalping strategy using EMA crossovers for rapid entry/exit signals on 1-minute timeframes.

**Characteristics**:
- ⏰ **Timeframe**: 1m (scalping)
- 📈 **Stop Loss**: 2%
- 🎯 **Take Profit**: Aggressive ROI (3% immediate)
- 🔄 **Trailing Stop**: Disabled for quick exits
- 💰 **Stake**: $5 USDT per trade
- 📊 **Leverage**: 10x
- 🎲 **Max Trades**: 10 simultaneous

**Entry Signals**:
- EMA 5 crosses above EMA 10
- EMA 10 > EMA 21 (trend confirmation)
- RSI between 30-70 (avoid extremes)
- Volume > 1.5x average
- Price action momentum

**Exit Signals**:
- EMA 5 crosses below EMA 10
- RSI > 70 or RSI < 30
- Stop loss/Take profit triggered
- Quick profit taking (3% target)

### 2. Bollinger Squeeze Scalping Strategy (`BollingerSqueezeScalpStrategy`)

**Description**: Volatility breakout scalping strategy that detects Bollinger Bands squeeze conditions and trades the subsequent breakouts.

**Characteristics**:
- ⏰ **Timeframe**: 5m (short-term scalping)
- 📈 **Stop Loss**: 2.5%
- 🎯 **Take Profit**: Quick scalping targets
- 🔄 **Trailing Stop**: Disabled for rapid exits
- 💰 **Stake**: $5 USDT per trade
- 📊 **Leverage**: 10x
- 🎲 **Max Trades**: 8 simultaneous

**Entry Signals**:
- Bollinger Bands squeeze detected (low volatility)
- Price breakout above/below squeeze range
- Volume spike (>2x average) confirming breakout
- Keltner Channel confirmation
- Momentum indicators alignment

**Exit Signals**:
- Bollinger Bands expansion completes
- Volume returns to normal levels
- Opposite squeeze signal
- Stop loss/Take profit triggered

## ⚙️ Configuration

### API Configuration

1. **Create a `.env` file** in the project root:

```bash
# Exchange APIs (Bybit)
export FREQTRADE_API_KEY="your_bybit_api_key"
export FREQTRADE_API_SECRET="your_bybit_api_secret"

# Telegram (optional)
export TELEGRAM_TOKEN="your_bot_token"
export TELEGRAM_CHAT_ID="your_chat_id"
```

2. **Load environment variables**:

```bash
source .env
```

### Ready-to-use Configurations

- **EMA Scalping Strategy**: `user_data/config/ema_scalping_config.json`
- **Bollinger Squeeze Strategy**: `user_data/config/bollinger_squeeze_config.json`

### Project Structure

```
cryptotrader/
├── user_data/
│   ├── strategies/
│   │   ├── EMAScalpingStrategy.py
│   │   └── BollingerSqueezeScalpStrategy.py
│   └── config/
│       ├── config.json                      # ← Base exchange configuration
│       ├── ema_scalping_config.json         # ← EMA scalping specific config
│       └── bollinger_squeeze_config.json    # ← Bollinger squeeze specific config
├── .env                                     # ← Credentials (not in git)
├── .env.example                             # ← Credentials example
├── run_strategy.sh
├── monitor.sh
└── README.md
```

**Configuration Inheritance**: All config files inherit exchange settings (`name`, `key`, `secret`) from the base `config.json`.

## 🎮 How to Use

### 1. Dry Run Mode (Simulation)

```bash
# Activate virtual environment
source /home/marcos/projects/cryptotrader/freqtrade/.venv/bin/activate

# EMA Scalping (Dry Run)
freqtrade trade \
    --config user_data/config/ema_scalping_config.json \
    --strategy EMAScalpingStrategy \
    --userdir user_data \
    --dry-run

# Bollinger Squeeze (Dry Run)
freqtrade trade \
    --config user_data/config/bollinger_squeeze_config.json \
    --strategy BollingerSqueezeScalpStrategy \
    --userdir user_data \
    --dry-run
```

### 2. Live Mode (Real Trading)

⚠️ **WARNING**: Always test in dry-run first!

```bash
# EMA Scalping (LIVE)
freqtrade trade \
    --config user_data/config/ema_scalping_config.json \
    --strategy EMAScalpingStrategy \
    --userdir user_data

# Bollinger Squeeze (LIVE)
freqtrade trade \
    --config user_data/config/bollinger_squeeze_config.json \
    --strategy BollingerSqueezeScalpStrategy \
    --userdir user_data
```

### 3. Web Interface

```bash
# Start web interface
freqtrade webserver --config user_data/config/ema_scalping_config.json

# Access: http://localhost:8080
# User: freqtrader
# Password: SuperSecretPassword
```

### 4. Using the Run Script

```bash
# EMA scalping in simulation mode
./run_strategy.sh ema dry

# Bollinger squeeze in simulation mode
./run_strategy.sh bb dry

# Live trading (use with caution)
./run_strategy.sh ema live
./run_strategy.sh bb live
```

## 📈 Backtesting

### Data Download

```bash
# Download data for EMA Scalping (1m, 30 days)
freqtrade download-data \
    --config user_data/config/ema_scalping_config.json \
    --timeframe 1m \
    --days 30

# Download data for Bollinger Squeeze (5m, 60 days)
freqtrade download-data \
    --config user_data/config/bollinger_squeeze_config.json \
    --timeframe 5m \
    --days 60
```

### Run Backtests

```bash
# Backtest EMA Scalping Strategy
freqtrade backtesting \
    --config user_data/config/ema_scalping_config.json \
    --strategy EMAScalpingStrategy \
    --userdir user_data \
    --timerange 20231001-20241030

# Backtest Bollinger Squeeze Strategy
freqtrade backtesting \
    --config user_data/config/bollinger_squeeze_config.json \
    --strategy BollingerSqueezeScalpStrategy \
    --userdir user_data \
    --timerange 20231001-20241030

# Backtest with detailed analysis
freqtrade backtesting \
    --config user_data/config/ema_scalping_config.json \
    --strategy EMAScalpingStrategy \
    --userdir user_data \
    --timerange 20231001-20241030 \
    --breakdown month week
```

## 🔧 Parameter Optimization

### Hyperopt - Automatic Optimization

```bash
# Optimize EMA Scalping Strategy (100 epochs)
freqtrade hyperopt \
    --config user_data/config/ema_scalping_config.json \
    --strategy EMAScalpingStrategy \
    --userdir user_data \
    --hyperopt-loss SharpeHyperOptLoss \
    --epochs 100 \
    --spaces buy sell

# Optimize Bollinger Squeeze Strategy (200 epochs)
freqtrade hyperopt \
    --config user_data/config/bollinger_squeeze_config.json \
    --strategy BollingerSqueezeScalpStrategy \
    --userdir user_data \
    --hyperopt-loss SortinoHyperOptLoss \
    --epochs 200 \
    --spaces buy sell

# View optimization results
freqtrade hyperopt-list --best 10
freqtrade hyperopt-show -n 1
```

### Available Optimization Spaces

- **buy**: Entry parameters
- **sell**: Exit parameters
- **roi**: ROI table
- **stoploss**: Stop loss
- **trailing**: Trailing stop

## 📊 Monitoring

### Useful Commands

```bash
# Real-time bot status
freqtrade status

# Trade history
freqtrade show_trades --db-url sqlite:///tradesv3.sqlite

# Performance per pair
freqtrade show_trades --db-url sqlite:///tradesv3.sqlite --print-json | jq

# Analysis plots
freqtrade plot-dataframe \
    --config user_data/config/ema_scalping_config.json \
    --strategy EMAScalpingStrategy \
    --userdir user_data \
    --pair BTC/USDT
```

### Logs and Debugging

```bash
# Monitor real-time logs
tail -f ~/freqtrade/user_data/logs/freqtrade.log

# Debug level logs
freqtrade trade \
    --config config/ema_scalping_config.json \
    --strategy EMAScalpingStrategy \
    --dry-run \
    --loglevel DEBUG
```

## 🔒 Security and Best Practices

### ⚡ Leverage Configuration

**IMPORTANT**: The strategies are configured with 10x leverage to maximize returns, but this significantly increases risks:

- **Stake per trade**: $5 USDT
- **Real exposure**: $50 USDT per trade (5 × 10x)
- **High risk**: Losses can be 10x larger
- **Required margin**: Less initial capital needed

### ⚠️ Risk Management with Leverage

```json
{
    "protections": [
        {
            "method": "StoplossGuard",
            "lookback_period_candles": 60,
            "trade_limit": 3,
            "stop_duration_candles": 120,
            "only_per_pair": false
        },
        {
            "method": "MaxDrawdown", 
            "lookback_period_candles": 200,
            "trade_limit": 15,
            "stop_duration_candles": 200,
            "max_allowed_drawdown": 0.15
        }
    ]
}
```

### ✅ Security Checklist

- [ ] **Always test in dry-run first**
- [ ] **Use environment variables for API keys**
- [ ] **Understand 10x leverage risks**
- [ ] **Monitor available margin constantly**
- [ ] **Set strict stop loss**
- [ ] **Use only 1-2% of total capital**
- [ ] **Monitor regularly**
- [ ] **Keep organized logs**
- [ ] **Backup configurations**
- [ ] **NEVER invest more than you can afford to lose**

### 🛡️ Configurações de Proteção

```json
{
    "protections": [
        {
            "method": "StoplossGuard",
            "lookback_period_candles": 60,
            "trade_limit": 4,
            "stop_duration_candles": 60,
            "only_per_pair": false
        },
        {
            "method": "MaxDrawdown",
            "lookback_period_candles": 200,
            "trade_limit": 20,
            "stop_duration_candles": 100,
            "max_allowed_drawdown": 0.2
        }
    ]
}
```

## 📋 Essential Commands

### Initial Setup

```bash
# 1. Activate virtual environment
source /home/marcos/projects/cryptotrader/freqtrade/.venv/bin/activate

# 2. Verify installation
freqtrade --version

# 3. Configure environment variables (ready in .env)
source .env
```

### Daily Operation

```bash
# Start trading (dry-run)
freqtrade trade --config user_data/config/ema_scalping_config.json --strategy EMAScalpingStrategy --userdir user_data --dry-run

# Check status
freqtrade status

# Stop bot safely
Ctrl+C (or freqtrade stop)

# Update data
freqtrade download-data --config user_data/config/ema_scalping_config.json --days 1
```

## 🆘 Troubleshooting

### Common Issues

1. **Import error**: `pip install freqtrade[all] --upgrade`
2. **API not working**: Check keys and permissions
3. **No entry signals**: Check parameters and data
4. **Poor performance**: Run backtest and optimization

### Support

- 📖 [FreqTrade Documentation](https://www.freqtrade.io/)
- 💬 [FreqTrade Discord](https://discord.gg/p7nuUNVfP7)
- 🐛 [Project Issues](https://github.com/marcosrioj/cryptotrader/issues)

---

## ⚠️ Disclaimer

**⚡ This software uses 10x leverage and is configured for FUTURES trading. Risks are extremely high:**

- **10x Leverage**: Gains and losses are multiplied by 10
- **Futures Trading**: More volatile market than spot
- **Mandatory Stop Loss**: 2-2.5% can result in 20-25% real loss
- **Margin**: Always monitor your available margin
- **Minimum recommended capital**: $500-1000 USDT to operate safely

**Always:**

- Test strategies in dry-run mode
- Perform extensive backtests
- Use only capital you can afford to lose
- Monitor your positions regularly
- Stay updated with market conditions

**We are not responsible for financial losses.**

---

**🚀 Happy Trading!**