# Bollinger Bands Squeeze Scalping Strategy
# Estratégia de scalping baseada em Bollinger Bands e squeeze de volatilidade
# Otimizada para capturar movimentos rápidos após baixa volatilidade

import talib.abstract as ta
from freqtrade.strategy import IStrategy, DecimalParameter, IntParameter
from pandas import DataFrame
import numpy as np


class BollingerSqueezeScalpStrategy(IStrategy):
    """
    Estratégia Bollinger Bands Squeeze Scalping
    
    Esta estratégia utiliza:
    - Bollinger Bands para identificar squeeze de volatilidade
    - RSI para momentum
    - Volume para confirmação de breakout
    - ADX para força da tendência
    
    Sinais de compra:
    - Bollinger Bands em squeeze (baixa volatilidade)
    - Preço quebra acima da banda superior
    - RSI > 50 (momentum de alta)
    - Volume spike (2x média)
    - ADX > 20 (tendência se formando)
    
    Sinais de venda:
    - Preço quebra abaixo da banda inferior
    - RSI < 50 (momentum de baixa)
    - Ou stop loss/take profit
    """

    # Configurações básicas da estratégia
    INTERFACE_VERSION = 3
    
    # Configurações de risco para scalping
    stoploss = -0.025  # Stop loss de 2.5%
    
    # Timeframe para scalping
    timeframe = '5m'  # 5 minutos para menos ruído que 1m
    
    # Trailing stop
    trailing_stop = True
    trailing_stop_positive = 0.008  # 0.8%
    trailing_stop_positive_offset = 0.015  # 1.5%
    trailing_only_offset_is_reached = True
    
    # ROI otimizado para scalping
    minimal_roi = {
        "0": 0.04,    # 4% imediato
        "5": 0.025,   # 2.5% após 5 minutos
        "10": 0.02,   # 2% após 10 minutos
        "20": 0.015,  # 1.5% após 20 minutos
        "30": 0.01    # 1% após 30 minutos
    }
    
    # Parâmetros otimizáveis
    bb_period = IntParameter(15, 25, default=20, space="buy")
    bb_std = DecimalParameter(1.8, 2.2, default=2.0, space="buy")
    
    rsi_period = IntParameter(10, 16, default=14, space="buy")
    rsi_buy_threshold = IntParameter(45, 55, default=50, space="buy")
    rsi_sell_threshold = IntParameter(45, 55, default=50, space="sell")
    
    volume_spike = DecimalParameter(1.8, 3.0, default=2.0, space="buy")
    
    adx_period = IntParameter(12, 18, default=14, space="buy")
    adx_threshold = IntParameter(18, 25, default=20, space="buy")
    
    squeeze_threshold = DecimalParameter(0.01, 0.03, default=0.02, space="buy")
    
    # Configurações de proteção
    use_exit_signal = True
    exit_profit_only = False
    ignore_roi_if_entry_signal = False
    
    startup_candle_count: int = 40

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Adiciona indicadores técnicos para squeeze scalping
        """
        
        # Bollinger Bands
        bollinger = ta.BBANDS(
            dataframe, 
            timeperiod=self.bb_period.value, 
            nbdevup=self.bb_std.value,
            nbdevdn=self.bb_std.value
        )
        dataframe['bb_lowerband'] = bollinger['lowerband']
        dataframe['bb_middleband'] = bollinger['middleband']
        dataframe['bb_upperband'] = bollinger['upperband']
        
        # Bollinger Band Width (para detectar squeeze)
        dataframe['bb_width'] = (
            (dataframe['bb_upperband'] - dataframe['bb_lowerband']) / 
            dataframe['bb_middleband']
        )
        
        # Squeeze detection
        dataframe['bb_squeeze'] = dataframe['bb_width'] < self.squeeze_threshold.value
        
        # Bollinger Band position
        dataframe['bb_percent'] = (
            (dataframe['close'] - dataframe['bb_lowerband']) / 
            (dataframe['bb_upperband'] - dataframe['bb_lowerband'])
        )
        
        # Breakouts
        dataframe['bb_break_up'] = (
            (dataframe['close'] > dataframe['bb_upperband']) &
            (dataframe['close'].shift(1) <= dataframe['bb_upperband'].shift(1))
        )
        dataframe['bb_break_down'] = (
            (dataframe['close'] < dataframe['bb_lowerband']) &
            (dataframe['close'].shift(1) >= dataframe['bb_lowerband'].shift(1))
        )
        
        # RSI
        dataframe['rsi'] = ta.RSI(dataframe, timeperiod=self.rsi_period.value)
        
        # Volume analysis
        dataframe['volume_sma'] = ta.SMA(dataframe['volume'], timeperiod=20)
        dataframe['volume_ratio'] = dataframe['volume'] / dataframe['volume_sma']
        
        # ADX para força da tendência
        dataframe['adx'] = ta.ADX(dataframe, timeperiod=self.adx_period.value)
        
        # MACD para momentum adicional
        macd = ta.MACD(dataframe)
        dataframe['macd'] = macd['macd']
        dataframe['macdsignal'] = macd['macdsignal']
        dataframe['macdhist'] = macd['macdhist']
        
        # EMA rápida para direção
        dataframe['ema_fast'] = ta.EMA(dataframe, timeperiod=9)
        
        # Keltner Channels (para comparar com BB)
        dataframe['kc_upper'] = dataframe['bb_middleband'] + (ta.ATR(dataframe, timeperiod=20) * 2)
        dataframe['kc_lower'] = dataframe['bb_middleband'] - (ta.ATR(dataframe, timeperiod=20) * 2)
        
        # True squeeze (BB dentro de Keltner)
        dataframe['true_squeeze'] = (
            (dataframe['bb_upperband'] < dataframe['kc_upper']) &
            (dataframe['bb_lowerband'] > dataframe['kc_lower'])
        )
        
        # ATR para stop loss dinâmico
        dataframe['atr'] = ta.ATR(dataframe, timeperiod=14)
        
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Sinais de entrada baseados em squeeze e breakout
        """
        
        conditions = []
        
        # Condição 1: Squeeze recente (nas últimas 3 velas)
        dataframe['recent_squeeze'] = (
            dataframe['bb_squeeze'] | 
            dataframe['bb_squeeze'].shift(1) | 
            dataframe['bb_squeeze'].shift(2) |
            dataframe['true_squeeze'] |
            dataframe['true_squeeze'].shift(1)
        )
        conditions.append(dataframe['recent_squeeze'])
        
        # Condição 2: Breakout para cima
        conditions.append(dataframe['bb_break_up'])
        
        # Condição 3: RSI com momentum de alta
        conditions.append(dataframe['rsi'] > self.rsi_buy_threshold.value)
        
        # Condição 4: Volume spike confirmando breakout
        conditions.append(dataframe['volume_ratio'] > self.volume_spike.value)
        
        # Condição 5: ADX mostrando força na tendência
        conditions.append(dataframe['adx'] > self.adx_threshold.value)
        
        # Condição 6: MACD positivo
        conditions.append(dataframe['macdhist'] > 0)
        
        # Condição 7: Preço acima da EMA rápida
        conditions.append(dataframe['close'] > dataframe['ema_fast'])
        
        # Condição 8: Não em zona de sobrecompra extrema
        conditions.append(dataframe['bb_percent'] < 0.95)
        
        if conditions:
            dataframe.loc[
                np.logical_and.reduce(conditions),
                'enter_long'
            ] = 1
            
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Sinais de saída para scalping squeeze
        """
        
        conditions = []
        
        # Condição principal: Breakout para baixo
        conditions.append(dataframe['bb_break_down'])
        
        # Condições alternativas
        alt_conditions = []
        
        # RSI perdendo momentum
        alt_conditions.append(dataframe['rsi'] < self.rsi_sell_threshold.value)
        
        # Preço volta para dentro das bandas após extensão
        alt_conditions.append(
            (dataframe['bb_percent'] > 0.8) & 
            (dataframe['close'] < dataframe['bb_upperband'])
        )
        
        # MACD virando negativo
        alt_conditions.append(
            (dataframe['macd'] < dataframe['macdsignal']) &
            (dataframe['macdhist'] < 0)
        )
        
        # Volume diminuindo após spike
        alt_conditions.append(
            (dataframe['volume_ratio'] < 1.0) &
            (dataframe['volume_ratio'].shift(1) > 2.0)
        )
        
        # Preço abaixo da EMA rápida
        alt_conditions.append(dataframe['close'] < dataframe['ema_fast'])
        
        # Combinar condições
        main_exit = np.logical_and.reduce(conditions) if conditions else False
        alt_exit = np.logical_and.reduce(alt_conditions) if alt_conditions else False
        
        dataframe.loc[main_exit | alt_exit, 'exit_long'] = 1
        
        return dataframe

    def custom_stoploss(self, pair: str, trade, current_time, current_rate, 
                       current_profit, **kwargs):
        """
        Stop loss baseado em ATR
        """
        dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last_candle = dataframe.iloc[-1].squeeze()
        
        # Stop loss baseado em ATR
        atr_multiplier = 2.0
        atr_stop = atr_multiplier * last_candle['atr'] / current_rate
        
        return max(-atr_stop, self.stoploss)

    def custom_exit(self, pair: str, trade, current_time, current_rate,
                   current_profit, **kwargs):
        """
        Saídas personalizadas para squeeze scalping
        """
        dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last_candle = dataframe.iloc[-1].squeeze()
        
        # Saída rápida com lucro alto
        if current_profit > 0.03:
            return 'high_profit_exit'
        
        # Saída se squeeze voltou (fim do movimento)
        if current_profit > 0.01 and last_candle['bb_squeeze']:
            return 'squeeze_return_exit'
        
        # Saída se RSI extremo
        if current_profit > 0.008 and last_candle['rsi'] > 75:
            return 'rsi_extreme_exit'
        
        return None

    def leverage(self, pair: str, current_time, current_rate,
                proposed_leverage: float, max_leverage: float, entry_tag, side: str,
                **kwargs) -> float:
        """
        Alavancagem para scalping
        """
        return 10.0  # Alavancagem 10x (configurar manualmente na Bybit)