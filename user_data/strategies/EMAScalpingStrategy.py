# EMA Crossover Scalping Strategy
# Estratégia de scalping baseada em cruzamento de EMAs rápidas
# Otimizada para timeframes de 1m e 5m

import talib.abstract as ta
from freqtrade.strategy import IStrategy, DecimalParameter, IntParameter
from pandas import DataFrame
import numpy as np
import pandas as pd
from datetime import timedelta


class EMAScalpingStrategy(IStrategy):
    """
    Estratégia EMA Crossover Scalping
    
    Esta estratégia utiliza:
    - EMAs rápidas (5, 10, 21) para sinais de entrada/saída
    - RSI para evitar extremos
    - Volume para confirmação
    - Stop loss apertado para scalping
    
    Sinais de compra:
    - EMA 5 cruza acima da EMA 10
    - EMA 10 acima da EMA 21 (tendência de alta)
    - RSI entre 30-70 (não em extremos)
    - Volume acima da média
    
    Sinais de venda:
    - EMA 5 cruza abaixo da EMA 10
    - Ou RSI > 75
    - Ou stop loss/take profit
    """

    # Configurações básicas da estratégia
    INTERFACE_VERSION = 3
    
    # Configurações de risco para scalping
    stoploss = -0.02  # Stop loss de 2% (apertado para scalping)
    
    # Configurações de timeframe
    timeframe = '1m'  # Scalping em 1 minuto
    
    # Configurações de trailing stop
    trailing_stop = True
    trailing_stop_positive = 0.005  # 0.5%
    trailing_stop_positive_offset = 0.01  # 1%
    trailing_only_offset_is_reached = True
    
    # ROI agressivo para scalping
    minimal_roi = {
        "0": 0.03,    # 3% imediato
        "3": 0.02,    # 2% após 3 minutos
        "5": 0.015,   # 1.5% após 5 minutos
        "10": 0.01,   # 1% após 10 minutos
        "15": 0.005   # 0.5% após 15 minutos
    }
    
    # Parâmetros otimizáveis
    ema_fast = IntParameter(3, 8, default=5, space="buy")
    ema_medium = IntParameter(8, 15, default=10, space="buy")
    ema_slow = IntParameter(18, 25, default=21, space="buy")
    
    rsi_period = IntParameter(10, 16, default=14, space="buy")
    rsi_buy_min = IntParameter(25, 35, default=30, space="buy")
    rsi_buy_max = IntParameter(65, 75, default=70, space="buy")
    rsi_sell_threshold = IntParameter(70, 80, default=75, space="sell")
    
    volume_factor = DecimalParameter(1.2, 2.0, default=1.5, space="buy")
    
    # Configurações de proteção
    use_exit_signal = True
    exit_profit_only = False
    ignore_roi_if_entry_signal = False
    
    startup_candle_count: int = 30

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Adiciona indicadores técnicos ao dataframe
        """
        
        # EMAs para crossover
        dataframe['ema_fast'] = ta.EMA(dataframe, timeperiod=self.ema_fast.value)
        dataframe['ema_medium'] = ta.EMA(dataframe, timeperiod=self.ema_medium.value)
        dataframe['ema_slow'] = ta.EMA(dataframe, timeperiod=self.ema_slow.value)
        
        # Crossovers
        dataframe['ema_cross_up'] = (
            (dataframe['ema_fast'] > dataframe['ema_medium']) &
            (dataframe['ema_fast'].shift(1) <= dataframe['ema_medium'].shift(1))
        )
        dataframe['ema_cross_down'] = (
            (dataframe['ema_fast'] < dataframe['ema_medium']) &
            (dataframe['ema_fast'].shift(1) >= dataframe['ema_medium'].shift(1))
        )
        
        # Tendência
        dataframe['uptrend'] = dataframe['ema_medium'] > dataframe['ema_slow']
        dataframe['downtrend'] = dataframe['ema_medium'] < dataframe['ema_slow']
        
        # RSI
        dataframe['rsi'] = ta.RSI(dataframe, timeperiod=self.rsi_period.value)
        
        # Volume
        dataframe['volume_sma'] = ta.SMA(dataframe['volume'], timeperiod=10)
        dataframe['volume_ratio'] = dataframe['volume'] / dataframe['volume_sma']
        
        # MACD para confirmação adicional
        macd = ta.MACD(dataframe, fastperiod=12, slowperiod=26, signalperiod=9)
        dataframe['macd'] = macd['macd']
        dataframe['macdsignal'] = macd['macdsignal']
        dataframe['macdhist'] = macd['macdhist']
        
        # Bollinger Bands para volatilidade
        bollinger = ta.BBANDS(dataframe, timeperiod=20, nbdevup=2, nbdevdn=2)
        dataframe['bb_lowerband'] = bollinger['lowerband']
        dataframe['bb_upperband'] = bollinger['upperband']
        dataframe['bb_width'] = (bollinger['upperband'] - bollinger['lowerband']) / dataframe['close']
        
        # ATR para volatilidade
        dataframe['atr'] = ta.ATR(dataframe, timeperiod=14)
        
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Sinais de entrada para scalping
        """
        
        conditions = []
        
        # Condição principal: EMA crossover para cima
        conditions.append(dataframe['ema_cross_up'])
        
        # Tendência de alta
        conditions.append(dataframe['uptrend'])
        
        # RSI em zona neutra (não sobrecomprado/sobrevendido)
        conditions.append(dataframe['rsi'] >= self.rsi_buy_min.value)
        conditions.append(dataframe['rsi'] <= self.rsi_buy_max.value)
        
        # Volume confirmando
        conditions.append(dataframe['volume_ratio'] > self.volume_factor.value)
        
        # MACD momentum positivo
        conditions.append(dataframe['macdhist'] > 0)
        
        # Volatilidade adequada para scalping
        conditions.append(dataframe['bb_width'] > 0.015)
        
        # Preço acima da EMA lenta
        conditions.append(dataframe['close'] > dataframe['ema_slow'])
        
        if conditions:
            dataframe.loc[
                np.logical_and.reduce(conditions),
                'enter_long'
            ] = 1
            
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Sinais de saída para scalping
        """
        
        conditions = []
        
        # Condição principal: EMA crossover para baixo
        conditions.append(dataframe['ema_cross_down'])
        
        # Condições alternativas
        alt_conditions = []
        
        # RSI em sobrecompra
        alt_conditions.append(dataframe['rsi'] > self.rsi_sell_threshold.value)
        
        # MACD perdendo momentum
        alt_conditions.append(
            (dataframe['macd'] < dataframe['macdsignal']) &
            (dataframe['macdhist'] < dataframe['macdhist'].shift(1))
        )
        
        # Quebra da tendência
        alt_conditions.append(dataframe['downtrend'])
        
        # Combinar condições
        main_exit = np.logical_and.reduce(conditions) if conditions else False
        alt_exit = np.logical_or.reduce(alt_conditions) if alt_conditions else False
        
        dataframe.loc[main_exit | alt_exit, 'exit_long'] = 1
        
        return dataframe

    def custom_stoploss(self, pair: str, trade, current_time, current_rate, 
                       current_profit, **kwargs):
        """
        Stop loss dinâmico baseado em ATR para scalping
        """
        dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last_candle = dataframe.iloc[-1].squeeze()
        
        # Stop loss baseado em ATR (mais apertado para scalping)
        atr_multiplier = 1.5
        atr_stop = atr_multiplier * last_candle['atr'] / current_rate
        
        # Não pode ser menor que o stop loss fixo
        return max(-atr_stop, self.stoploss)

    def custom_exit(self, pair: str, trade, current_time, current_rate,
                   current_profit, **kwargs):
        """
        Saídas personalizadas para scalping
        """
        dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last_candle = dataframe.iloc[-1].squeeze()
        
        # Saída rápida se lucro alto em pouco tempo
        if current_profit > 0.02 and (current_time - trade.open_date_utc.replace(tzinfo=None)).total_seconds() < 120:
            return 'quick_profit_scalp'
        
        # Saída se RSI extremo e lucro positivo
        if current_profit > 0.005 and last_candle['rsi'] > 80:
            return 'rsi_extreme_exit'
        
        return None

    def leverage(self, pair: str, current_time, current_rate,
                proposed_leverage: float, max_leverage: float, entry_tag, side: str,
                **kwargs) -> float:
        """
        Alavancagem para scalping
        """
        return 10.0  # Alavancagem 10x (configurar manualmente na Bybit)