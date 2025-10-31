# CryptoTrader - FreqTrade Strategies

Este repositório contém estratégias de trading automatizado para criptomoedas usando FreqTrade, incluindo duas das estratégias mais populares e testadas da comunidade.

## 📋 Índice

- [Instalação](#instalação)
- [Estratégias Disponíveis](#estratégias-disponíveis)
- [Configuração](#configuração)
- [Como Usar](#como-usar)
- [Backtesting](#backtesting)
- [Otimização](#otimização)
- [Monitoramento](#monitoramento)
- [Segurança](#segurança)

## 🚀 Instalação

Siga o guia completo de instalação em [FREQTRADE_INSTALLATION_GUIDE.md](./FREQTRADE_INSTALLATION_GUIDE.md)

### Instalação Rápida

```bash
# Clonar o repositório
git clone https://github.com/marcosrioj/cryptotrader.git
cd cryptotrader

# Seguir os passos do guia de instalação do FreqTrade
# As estratégias e configurações já estão organizadas em user_data/

# Configuração automática do ambiente
./setup_environment.sh
```

## 📊 Estratégias Disponíveis

**Exchange Configurada**: Bybit Futures
**Formato dos Pares**: `SYMBOL/USDT:USDT` (ex: `BTC/USDT:USDT`)

### 1. RSI + Bollinger Bands Strategy (`RSIBBStrategy`)

**Descrição**: Uma das estratégias mais populares que combina RSI para identificar condições de sobrecompra/sobrevenda com Bollinger Bands para níveis de suporte e resistência.

**Características**:
- ⏰ **Timeframe**: 1h (recomendado)
- 📈 **Stop Loss**: 5%
- 🎯 **Take Profit**: ROI escalonado (15% → 2%)
- 🔄 **Trailing Stop**: Ativado
- 💰 **Stake**: $5 USDT por trade
- 📊 **Alavancagem**: 10x
- 🎲 **Max Trades**: 8 simultâneos

**Sinais de Entrada**:
- RSI < 30 (sobrevenda)
- Preço toca banda inferior do Bollinger
- Volume acima da média (1.5x)
- MACD em território positivo
- ADX > 20 (força da tendência)

**Sinais de Saída**:
- RSI > 70 (sobrecompra)
- Preço toca banda superior do Bollinger
- MACD cruza para baixo
- Stop loss/Take profit

### 2. MACD + EMA Strategy (`MACDEMAStrategy`)

**Descrição**: Estratégia clássica baseada em MACD para sinais de entrada/saída com filtro de tendência usando médias móveis exponenciais.

**Características**:
- ⏰ **Timeframe**: 4h (recomendado)
- 📈 **Stop Loss**: 6%
- 🎯 **Take Profit**: ROI escalonado (20% → 2%)
- 🔄 **Trailing Stop**: Ativado
- 💰 **Stake**: $5 USDT por trade
- 📊 **Alavancagem**: 10x
- 🎲 **Max Trades**: 6 simultâneos

**Sinais de Entrada**:
- MACD cruza acima da linha de sinal
- Preço em tendência de alta (EMA 12 > EMA 21 > EMA 50)
- Volume > 1.8x da média
- RSI < 70 (não sobrecompra)
- ADX > 25 (tendência forte)

**Sinais de Saída**:
- MACD cruza abaixo da linha de sinal
- Quebra da estrutura de tendência
- RSI > 80 (sobrecompra extrema)
- Stop loss/Take profit

## ⚙️ Configuração

### Configuração das APIs

1. **Crie um arquivo `.env`** na raiz do projeto:

```bash
# APIs da Exchange (Bybit)
export FREQTRADE_API_KEY="sua_api_key_bybit"
export FREQTRADE_API_SECRET="sua_api_secret_bybit"

# Telegram (opcional)
export TELEGRAM_TOKEN="seu_bot_token"
export TELEGRAM_CHAT_ID="seu_chat_id"
```

2. **Carregue as variáveis de ambiente**:

```bash
source .env
```

### Configurações Prontas

- **RSI + BB Strategy**: `user_data/config/rsi_bb_config.json`
- **MACD + EMA Strategy**: `user_data/config/macd_ema_config.json`

### Estrutura do Projeto

```
cryptotrader/
├── user_data/
│   ├── strategies/
│   │   ├── RSIBBStrategy.py
│   │   └── MACDEMAStrategy.py
│   └── config/
│       ├── config.json              # ← Configuração base da exchange
│       ├── rsi_bb_config.json       # ← Config específica RSI+BB
│       └── macd_ema_config.json     # ← Config específica MACD+EMA
├── .env                             # ← Credenciais (não no git)
├── .env.example                     # ← Exemplo de credenciais
├── run_strategy.sh
├── monitor.sh
└── README.md
```

**Herança de Configuração**: Todos os arquivos de config herdam as configurações da exchange (`name`, `key`, `secret`) do `config.json` base.

## 🎮 Como Usar

### 1. Modo Dry Run (Simulação)

```bash
# Ativar ambiente virtual
source /home/marcos/projects/cryptotrader/freqtrade/.venv/bin/activate

# RSI + Bollinger Bands (Dry Run)
freqtrade trade \
    --config user_data/config/rsi_bb_config.json \
    --strategy RSIBBStrategy \
    --userdir user_data \
    --dry-run

# MACD + EMA (Dry Run)
freqtrade trade \
    --config user_data/config/macd_ema_config.json \
    --strategy MACDEMAStrategy \
    --userdir user_data \
    --dry-run
```

### 2. Modo Live (Trading Real)

⚠️ **ATENÇÃO**: Teste sempre em dry-run primeiro!

```bash
# RSI + Bollinger Bands (LIVE)
freqtrade trade \
    --config user_data/config/rsi_bb_config.json \
    --strategy RSIBBStrategy \
    --userdir user_data

# MACD + EMA (LIVE)
freqtrade trade \
    --config user_data/config/macd_ema_config.json \
    --strategy MACDEMAStrategy \
    --userdir user_data
```

### 3. Web Interface

```bash
# Iniciar interface web
freqtrade webserver --config user_data/config/rsi_bb_config.json

# Acesse: http://localhost:8080
# Usuário: freqtrader
# Senha: SuperSecretPassword
```

## 📈 Backtesting

### Download de Dados

```bash
# Download dados para RSI + BB (1h, 30 dias)
freqtrade download-data \
    --config user_data/config/rsi_bb_config.json \
    --timeframe 1h \
    --days 30

# Download dados para MACD + EMA (4h, 60 dias)
freqtrade download-data \
    --config user_data/config/macd_ema_config.json \
    --timeframe 4h \
    --days 60
```

### Executar Backtests

```bash
# Backtest RSI + BB Strategy
freqtrade backtesting \
    --config user_data/config/rsi_bb_config.json \
    --strategy RSIBBStrategy \
    --userdir user_data \
    --timerange 20231001-20241030

# Backtest MACD + EMA Strategy
freqtrade backtesting \
    --config user_data/config/macd_ema_config.json \
    --strategy MACDEMAStrategy \
    --userdir user_data \
    --timerange 20231001-20241030

# Backtest com análise detalhada
freqtrade backtesting \
    --config user_data/config/rsi_bb_config.json \
    --strategy RSIBBStrategy \
    --userdir user_data \
    --timerange 20231001-20241030 \
    --breakdown month week
```

## 🔧 Otimização de Parâmetros

### Hyperopt - Otimização Automática

```bash
# Otimizar RSI + BB Strategy (100 épocas)
freqtrade hyperopt \
    --config user_data/config/rsi_bb_config.json \
    --strategy RSIBBStrategy \
    --userdir user_data \
    --hyperopt-loss SharpeHyperOptLoss \
    --epochs 100 \
    --spaces buy sell

# Otimizar MACD + EMA Strategy (200 épocas)
freqtrade hyperopt \
    --config user_data/config/macd_ema_config.json \
    --strategy MACDEMAStrategy \
    --userdir user_data \
    --hyperopt-loss SortinoHyperOptLoss \
    --epochs 200 \
    --spaces buy sell

# Ver resultados da otimização
freqtrade hyperopt-list --best 10
freqtrade hyperopt-show -n 1
```

### Espaços de Otimização Disponíveis

- **buy**: Parâmetros de entrada
- **sell**: Parâmetros de saída
- **roi**: Tabela ROI
- **stoploss**: Stop loss
- **trailing**: Trailing stop

## 📊 Monitoramento

### Comandos Úteis

```bash
# Status do bot em tempo real
freqtrade status

# Histórico de trades
freqtrade show_trades --db-url sqlite:///tradesv3.sqlite

# Performance por par
freqtrade show_trades --db-url sqlite:///tradesv3.sqlite --print-json | jq

# Plots de análise
freqtrade plot-dataframe \
    --config user_data/config/rsi_bb_config.json \
    --strategy RSIBBStrategy \
    --userdir user_data \
    --pair BTC/USDT
```

### Logs e Debugging

```bash
# Monitorar logs em tempo real
tail -f ~/freqtrade/user_data/logs/freqtrade.log

# Logs com nível debug
freqtrade trade \
    --config config/rsi_bb_config.json \
    --strategy RSIBBStrategy \
    --dry-run \
    --loglevel DEBUG
```

## 🔒 Segurança e Melhores Práticas

### ⚡ Configuração de Alavancagem

**IMPORTANTE**: As estratégias estão configuradas com alavancagem 10x para maximizar retornos, mas isso aumenta significativamente os riscos:

- **Stake por trade**: $5 USDT
- **Exposição real**: $50 USDT por trade (5 × 10x)
- **Risco elevado**: Perdas podem ser 10x maiores
- **Margem necessária**: Menor capital inicial necessário

### ⚠️ Gestão de Risco com Alavancagem

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

### ✅ Checklist de Segurança

- [ ] **Sempre teste em dry-run primeiro**
- [ ] **Use variáveis de ambiente para API keys**
- [ ] **Entenda os riscos da alavancagem 10x**
- [ ] **Monitore margem disponível constantemente**
- [ ] **Defina stop loss rigoroso**
- [ ] **Use apenas 1-2% do capital total**
- [ ] **Monitore regularmente**
- [ ] **Mantenha logs organizados**
- [ ] **Faça backup das configurações**
- [ ] **NUNCA invista mais do que pode perder**

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

## 📋 Comandos Essenciais

### Setup Inicial

```bash
# 1. Ativar ambiente virtual
source /home/marcos/projects/cryptotrader/freqtrade/.venv/bin/activate

# 2. Verificar instalação
freqtrade --version

# 3. Configurar variáveis de ambiente (já prontas em .env)
source .env
```

### Operação Diária

```bash
# Iniciar trading (dry-run)
freqtrade trade --config user_data/config/rsi_bb_config.json --strategy RSIBBStrategy --userdir user_data --dry-run

# Verificar status
freqtrade status

# Parar bot com segurança
Ctrl+C (ou freqtrade stop)

# Atualizar dados
freqtrade download-data --config user_data/config/rsi_bb_config.json --days 1
```

## 🆘 Troubleshooting

### Problemas Comuns

1. **Erro de importação**: `pip install freqtrade[all] --upgrade`
2. **API não funcionando**: Verificar keys e permissões
3. **Sem sinais de entrada**: Verificar parâmetros e dados
4. **Performance ruim**: Fazer backtest e otimização

### Suporte

- 📖 [Documentação FreqTrade](https://www.freqtrade.io/)
- 💬 [Discord FreqTrade](https://discord.gg/p7nuUNVfP7)
- 🐛 [Issues do Projeto](https://github.com/marcosrioj/cryptotrader/issues)

---

## ⚠️ Disclaimer

**⚡ Este software utiliza alavancagem 10x e está configurado para FUTURES trading. Os riscos são extremamente elevados:**

- **Alavancagem 10x**: Ganhos e perdas são multiplicados por 10
- **Futures Trading**: Mercado mais volátil que spot
- **Stop Loss obrigatório**: 5-6% pode resultar em 50-60% de perda real
- **Margem**: Monitore sempre sua margem disponível
- **Capital mínimo recomendado**: $500-1000 USDT para operar com segurança

**Sempre:**

- Teste estratégias em modo dry-run
- Faça backtests extensivos
- Use apenas capital que pode perder
- Monitore regularmente suas posições
- Mantenha-se atualizado com o mercado

**Não nos responsabilizamos por perdas financeiras.**

---

**🚀 Happy Trading!**