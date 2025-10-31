# Configuração Bybit para FreqTrade Futures

Este guia detalha como configurar corretamente a Bybit para trading de futuros/perpetuais com FreqTrade.

## 🔧 Configuração da API Bybit

### 1. Criar API Key na Bybit

1. Acesse [Bybit API Management](https://www.bybit.com/app/user/api-management)
2. Clique em "Create New Key"
3. Configure as permissões necessárias:

#### ✅ Permissões Obrigatórias
- **Contract - Orders**: Read + Write
- **Contract - Positions**: Read + Write  
- **Wallet**: Read (opcional)
- **Account**: Read (opcional)

#### ❌ Permissões NÃO Recomendadas
- **Withdrawals**: Desabilitado (segurança)
- **Transfer**: Desabilitado (segurança)

### 2. Configurações da Conta Bybit

#### Position Mode
- Acesse: **Derivatives → Settings → Position Mode**
- Configure: **"One-way Mode"** 
- ⚠️ **IMPORTANTE**: FreqTrade requer este modo

#### Margin Mode
- Por padrão: **Isolated Margin** (recomendado)
- Cross Margin: Possível, mas maior risco

#### Alavancagem
- Configure manualmente na interface Bybit para cada par
- Recomendado: **10x** (configurar antes de iniciar o bot)

## ⚙️ Configuração FreqTrade

### Arquivo de Configuração Base

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

### Formato dos Pares

```json
"pair_whitelist": [
    "BTC/USDT:USDT",
    "ETH/USDT:USDT", 
    "SOL/USDT:USDT"
]
```

### Order Book Configuration (Obrigatório)

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

## 🚀 Processo de Setup

### 1. Configurar API Keys
```bash
# Editar .env
export FREQTRADE_API_KEY="sua_api_key_bybit"
export FREQTRADE_API_SECRET="sua_api_secret_bybit"
```

### 2. Configurar Bybit Web Interface

1. **Position Mode**: One-way Mode
2. **Alavancagem**: 10x para cada par que vai tradear
3. **Margin Mode**: Isolated (recomendado)

### 3. Testar Configuração

```bash
# Carregar ambiente
source .env

# Teste básico
freqtrade list-markets --exchange bybit --config user_data/config/rsi_bb_config.json

# Teste dry-run
./run_strategy.sh rsi dry
```

## ⚠️ Pontos Importantes

### Gestão de Risco
- **Stake**: $5 USDT por trade
- **Alavancagem**: 10x = $50 exposição por trade
- **Stop Loss**: 5-6% = 50-60% de perda real
- **Capital mínimo**: $500-1000 USDT recomendado

### Limitações Bybit
- **Funding Rates**: Não há histórico, FreqTrade usa cálculo dry-run
- **Position Mode**: Deve permanecer "One-way" durante trading
- **Account Type**: Recomendado usar subaccount dedicada

### Troubleshooting

#### Erro: "Freqtrade does not support 'futures' on Bybit"
- ✅ Solução: Usar `"defaultType": "swap"` e `"trading_mode": "futures"`

#### Erro: "Invalid symbol" 
- ✅ Solução: Usar formato `BTC/USDT:USDT` para perpetuais

#### Erro: "Insufficient permissions"
- ✅ Solução: Verificar permissões Contract Orders + Positions

#### Erro: "Position mode not supported"
- ✅ Solução: Configurar "One-way Mode" na Bybit

## 📊 Monitoramento

### Verificar Posições
```bash
# Via FreqTrade
freqtrade status

# Via Bybit API
curl -X GET "https://api.bybit.com/v5/position/list" \
  -H "X-BAPI-API-KEY: ${FREQTRADE_API_KEY}"
```

### Logs Importantes
```bash
# Monitorar funding fees
grep -i "funding" user_data/logs/freqtrade.log

# Monitorar alavancagem
grep -i "leverage" user_data/logs/freqtrade.log
```

## 🔒 Segurança

### API Keys
- ✅ Usar apenas permissões necessárias
- ✅ Restringir por IP se possível
- ✅ Rotacionar keys periodicamente
- ❌ Nunca dar permissão de withdrawal

### Conta
- ✅ Usar subaccount dedicada para bot
- ✅ Manter apenas capital necessário
- ✅ Monitorar regularmente
- ❌ Misturar trading manual com bot

## 📋 Checklist Final

- [ ] API Key criada com permissões corretas
- [ ] Position Mode = "One-way Mode"
- [ ] Alavancagem configurada (10x)
- [ ] Variáveis de ambiente configuradas
- [ ] Teste dry-run funcionando
- [ ] Monitoramento ativo
- [ ] Capital limitado na conta

---

**🎯 Pronto para trading com Bybit Perpetual Futures!**