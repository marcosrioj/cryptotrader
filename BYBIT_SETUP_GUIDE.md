# Bybit Setup for FreqTrade Futures

This guide details how to properly configure Bybit for futures/perpetual trading with FreqTrade.

## 🔧 Bybit API Configuration

### 1. Create API Key on Bybit

1. Access [Bybit API Management](https://www.bybit.com/app/user/api-management)
2. Click "Create New Key"
3. Configure the necessary permissions:

#### ✅ Required Permissions
- **Contract - Orders**: Read + Write
- **Contract - Positions**: Read + Write  
- **Wallet**: Read (optional)
- **Account**: Read (optional)

#### ❌ NOT Recommended Permissions
- **Withdrawals**: Disabled (security)
- **Transfer**: Disabled (security)

### 2. Bybit Account Settings

#### Position Mode
- Access: **Derivatives → Settings → Position Mode**
- Configure: **"One-way Mode"** 
- ⚠️ **IMPORTANT**: FreqTrade requires this mode

#### Margin Mode
- Default: **Isolated Margin** (recommended)
- Cross Margin: Possible, but higher risk

#### Leverage
- Configure manually in Bybit interface for each pair
- Recommended: **10x** (configure before starting the bot)

## ⚙️ FreqTrade Configuration

### Base Configuration File

```json
{
    "trading_mode": "futures",
    "margin_mode": "isolated", 
    "exchange": {
        "name": "bybit",
        "key": "${FREQTRADE_API_KEY}",
        "secret": "${FREQTRADE_API_SECRET}",
        "ccxt_config": {
            "enableRateLimit": true,
            "options": {
                "defaultType": "swap"
            }
        },
        "ccxt_async_config": {
            "enableRateLimit": true,
            "options": {
                "defaultType": "swap"
            }
        }
    }
}
```

### Pair Format

```json
"pair_whitelist": [
    "BTC/USDT:USDT",
    "ETH/USDT:USDT", 
    "SOL/USDT:USDT"
]
```

### Order Book Configuration (Required)

```json
"entry_pricing": {
    "use_order_book": true,
    "order_book_top": 1
},
"exit_pricing": {
    "use_order_book": true,
    "order_book_top": 1
}
```

## 🚀 Setup Process

### 1. Configure API Keys
```bash
# Edit .env
export FREQTRADE_API_KEY="your_bybit_api_key"
export FREQTRADE_API_SECRET="your_bybit_api_secret"
```

### 2. Configure Bybit Web Interface

1. **Position Mode**: One-way Mode
2. **Leverage**: 10x for each pair you'll trade
3. **Margin Mode**: Isolated (recommended)

### 3. Test Configuration

```bash
# Load environment
source .env

# Basic test
freqtrade list-markets --exchange bybit --config user_data/config/ema_scalping_config.json

# Dry-run test
./run_strategy.sh ema dry
```

## ⚠️ Important Points

### Risk Management
- **Stake**: $5 USDT per trade
- **Leverage**: 10x = $50 exposure per trade
- **Stop Loss**: 2-2.5% = 20-25% real loss
- **Minimum capital**: $500-1000 USDT recommended

### Bybit Limitations
- **Funding Rates**: No history available, FreqTrade uses dry-run calculation
- **Position Mode**: Must remain "One-way" during trading
- **Account Type**: Recommended to use dedicated subaccount

### Troubleshooting

#### Error: "Freqtrade does not support 'futures' on Bybit"
- ✅ Solution: Use `"defaultType": "swap"` and `"trading_mode": "futures"`

#### Error: "Invalid symbol" 
- ✅ Solution: Use format `BTC/USDT:USDT` for perpetuals

#### Error: "Insufficient permissions"
- ✅ Solution: Check Contract Orders + Positions permissions

#### Error: "Position mode not supported"
- ✅ Solution: Configure "One-way Mode" on Bybit

## 📊 Monitoring

### Check Positions
```bash
# Via FreqTrade
freqtrade status

# Via Bybit API
curl -X GET "https://api.bybit.com/v5/position/list" \
  -H "X-BAPI-API-KEY: ${FREQTRADE_API_KEY}"
```

### Important Logs
```bash
# Monitor funding fees
grep -i "funding" user_data/logs/freqtrade.log

# Monitor leverage
grep -i "leverage" user_data/logs/freqtrade.log
```

## 🔒 Security

### API Keys
- ✅ Use only necessary permissions
- ✅ Restrict by IP if possible
- ✅ Rotate keys periodically
- ❌ Never give withdrawal permissions

### Account
- ✅ Use dedicated subaccount for bot
- ✅ Keep only necessary capital
- ✅ Monitor regularly
- ❌ Mix manual trading with bot

## 📋 Final Checklist

- [ ] API Key created with correct permissions
- [ ] Position Mode = "One-way Mode"
- [ ] Leverage configured (10x)
- [ ] Environment variables configured
- [ ] Dry-run test working
- [ ] Active monitoring
- [ ] Limited capital in account

---

**🎯 Ready for trading with Bybit Perpetual Futures!**