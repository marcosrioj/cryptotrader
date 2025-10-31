# FreqTrade Installation Guide - Step by Step

This guide will walk you through installing FreqTrade from scratch on a Linux system.

## Prerequisites

Before starting, ensure you have:
- Python 3.8 or higher
- Git
- curl or wget
- A Linux/macOS system (Windows users should use WSL2)

## Step 1: System Updates and Dependencies

First, update your system and install required dependencies:

```bash
# Update package list
sudo apt update

# Install Python, pip, and development tools
sudo apt install -y python3 python3-pip python3-venv python3-dev

# Install build essentials and other dependencies
sudo apt install -y build-essential git curl wget

# Install additional libraries required for FreqTrade
sudo apt install -y libssl-dev libffi-dev libbz2-dev libreadline-dev libsqlite3-dev
```

## Step 2: Create a Dedicated Directory

Create a dedicated directory for your FreqTrade installation:

```bash
# Create directory for FreqTrade
mkdir -p ~/freqtrade
cd ~/freqtrade
```

## Step 3: Clone FreqTrade Repository

Clone the official FreqTrade repository:

```bash
# Clone FreqTrade from GitHub
git clone https://github.com/freqtrade/freqtrade.git
cd freqtrade

# Checkout the latest stable version (optional but recommended)
git checkout stable
```

## Step 4: Create Python Virtual Environment

Create and activate a Python virtual environment:

```bash
# Create virtual environment
python3 -m venv .venv

# Activate virtual environment
source .venv/bin/activate

# Verify you're in the virtual environment
which python
# Should show: /home/yourusername/freqtrade/freqtrade/.venv/bin/python
```

## Step 5: Install FreqTrade

Install FreqTrade and its dependencies:

```bash
# Upgrade pip first
pip install --upgrade pip

# Install FreqTrade with all dependencies
pip install -e .

# Alternative: Install from PyPI (if you don't want to clone the repo)
# pip install freqtrade[all]
```

## Step 6: Install Additional Dependencies (Optional but Recommended)

Install additional packages for enhanced functionality:

```bash
# Install plotting dependencies
pip install freqtrade[plot]

# Install hyperopt dependencies for strategy optimization
pip install freqtrade[hyperopt]

# Install all optional dependencies
pip install freqtrade[all]
```

## Step 7: Verify Installation

Verify that FreqTrade is installed correctly:

```bash
# Check FreqTrade version
freqtrade --version

# Test basic functionality
freqtrade --help
```

## Step 8: Create Configuration Directory

Create a directory for your FreqTrade configurations:

```bash
# Create config directory
mkdir -p ~/freqtrade/user_data/config
cd ~/freqtrade/user_data
```

## Step 9: Generate Sample Configuration

Generate a sample configuration file:

```bash
# Generate sample config
freqtrade create-userdir --userdir .

# This creates:
# - config.json (sample configuration)
# - strategies/ (directory for trading strategies)
# - data/ (directory for market data)
# - logs/ (directory for log files)
# - notebooks/ (directory for Jupyter notebooks)
```

## Step 10: Download Sample Data (Optional)

Download some sample data to test FreqTrade:

```bash
# Download sample data for backtesting
freqtrade download-data --exchange binance --pairs BTC/USDT ETH/USDT --timeframes 1h 4h 1d --days 30
```

## Step 11: Test with Dry Run

Test FreqTrade with a dry run (no real trading):

```bash
# Edit the config.json file first to set up your preferences
# Then run a dry run
freqtrade trade --config config.json --strategy SampleStrategy --dry-run
```

## Configuration Steps

### Step 12: Configure Exchange API

1. Edit `config.json`:
```json
{
    "exchange": {
        "name": "binance",
        "key": "your_api_key",
        "secret": "your_api_secret",
        "ccxt_config": {
            "enableRateLimit": true
        },
        "ccxt_async_config": {
            "enableRateLimit": true
        }
    }
}
```

2. **IMPORTANT**: Never commit API keys to version control!

### Step 13: Set Up Environment Variables (Recommended)

Instead of hardcoding API keys, use environment variables:

```bash
# Add to your ~/.bashrc or ~/.zshrc
export FREQTRADE_API_KEY="your_api_key"
export FREQTRADE_API_SECRET="your_api_secret"

# Reload your shell configuration
source ~/.bashrc
```

Then modify your config to use environment variables:
```json
{
    "exchange": {
        "name": "binance",
        "key": "${FREQTRADE_API_KEY}",
        "secret": "${FREQTRADE_API_SECRET}"
    }
}
```

## Useful Commands

### Daily Operations

```bash
# Always activate virtual environment first
source ~/freqtrade/freqtrade/.venv/bin/activate

# Start trading (dry run)
freqtrade trade --config config.json --strategy YourStrategy --dry-run

# Start trading (live - BE CAREFUL!)
freqtrade trade --config config.json --strategy YourStrategy

# Download fresh data
freqtrade download-data --config config.json

# Run backtesting
freqtrade backtesting --config config.json --strategy YourStrategy

# Start web UI
freqtrade webserver --config config.json
```

### Maintenance

```bash
# Update FreqTrade
cd ~/freqtrade/freqtrade
git pull
pip install -e . --upgrade

# Clean up old data
freqtrade clean-dry-run-db --config config.json
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure you're in the virtual environment
2. **Module Not Found**: Reinstall with `pip install -e . --force-reinstall`
3. **API Errors**: Check your API keys and permissions
4. **Database Errors**: Delete `tradesv3.sqlite` and restart

### Logs

Check logs for debugging:
```bash
tail -f ~/freqtrade/user_data/logs/freqtrade.log
```

## Security Best Practices

1. **Never share API keys**
2. **Use environment variables for sensitive data**
3. **Start with dry-run mode**
4. **Test strategies thoroughly with backtesting**
5. **Keep your FreqTrade installation updated**
6. **Use proper file permissions** (chmod 600 for config files)

## Next Steps

1. Study the [FreqTrade documentation](https://www.freqtrade.io/)
2. Learn about strategy development
3. Practice with backtesting
4. Join the FreqTrade community for support
5. Consider setting up monitoring and alerting

## Quick Start Script

Here's a one-liner to get started quickly:

```bash
#!/bin/bash
# Quick FreqTrade installation script
mkdir -p ~/freqtrade && cd ~/freqtrade
git clone https://github.com/freqtrade/freqtrade.git
cd freqtrade
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
freqtrade create-userdir --userdir ~/freqtrade/user_data
echo "FreqTrade installed! Activate with: source ~/freqtrade/freqtrade/.venv/bin/activate"
```

## Próximos Passos

Após a instalação, confira as estratégias prontas disponíveis no repositório:

1. **RSI + Bollinger Bands Strategy** - Estratégia popular para timeframes de 1h
2. **MACD + EMA Strategy** - Estratégia clássica para timeframes de 4h

Consulte o [README.md](./README.md) para instruções detalhadas sobre como usar essas estratégias.

---

**WARNING**: Trading cryptocurrencies involves significant risk. Always test thoroughly with dry-run mode before using real money. Never invest more than you can afford to lose.