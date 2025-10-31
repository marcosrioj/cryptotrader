# MACD + EMA Strategy
# Estratégia baseada em MACD e médias móveis exponenciais
# Uma das estratégias mais clássicas e confiáveis do trading

import talib.abstract as ta
from freqtrade.strategy import IStrategy, DecimalParameter, IntParameter, CategoricalParameter
from pandas import DataFrame
import numpy as np


class MACDEMAStrategy(IStrategy):
    """
    Estratégia MACD + EMA
    
    Esta estratégia utiliza:
    - MACD (Moving Average Convergence Divergence) para sinais de entrada/saída
    - EMAs (Exponential Moving Averages) para filtro de tendência
    - Volume para confirmação de sinais
    - RSI para evitar entradas em extremos
    
    Sinais de compra:
    - MACD cruza acima da linha de sinal
    - Preço acima da EMA longa (filtro de tendência de alta)
    - Volume acima da média
    - RSI não está em sobrecompra
    
    Sinais de venda:
    - MACD cruza abaixo da linha de sinal
    - Ou condições de stop loss/take profit
    """

    # Configurações básicas da estratégia
    INTERFACE_VERSION = 3
    
    # Configurações de risco
    stoploss = -0.06  # Stop loss de 6%
    
    # Configurações de timeframe
    timeframe = '4h'
    
    # Configurações de trailing stop
    trailing_stop = True
    trailing_stop_positive = 0.015
    trailing_stop_positive_offset = 0.025
    trailing_only_offset_is_reached = True
    
    # Configurações de ROI
    minimal_roi = {
        "0": 0.20,    # 20% após 0 minutos
        "120": 0.15,  # 15% após 2 horas
        "240": 0.10,  # 10% após 4 horas
        "480": 0.05,  # 5% após 8 horas
        "720": 0.02   # 2% após 12 horas
    }
    
    # Parâmetros otimizáveis para MACD
    macd_fast = IntParameter(8, 15, default=12, space="buy")
    macd_slow = IntParameter(20, 30, default=26, space="buy")
    macd_signal = IntParameter(7, 12, default=9, space="buy")
    
    # Parâmetros para EMAs
    ema_short = IntParameter(8, 15, default=12, space="buy")
    ema_medium = IntParameter(18, 25, default=21, space="buy")
    ema_long = IntParameter(45, 55, default=50, space="buy")
    
    # Parâmetros para RSI
    rsi_period = IntParameter(12, 18, default=14, space="buy")
    rsi_buy_max = IntParameter(65, 75, default=70, space="buy")
    rsi_sell_min = IntParameter(25, 35, default=30, space="sell")
    
    # Parâmetros para volume
    volume_factor = DecimalParameter(1.2, 2.5, default=1.8, space="buy")
    
    # Configurações de proteção
    use_exit_signal = True
    exit_profit_only = False
    ignore_roi_if_entry_signal = False
    
    startup_candle_count: int = 60

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Adiciona indicadores técnicos ao dataframe
        """
        
        # MACD - Indicador principal
        macd_data = ta.MACD(
            dataframe,
            fastperiod=self.macd_fast.value,
            slowperiod=self.macd_slow.value,
            signalperiod=self.macd_signal.value
        )
        dataframe['macd'] = macd_data['macd']
        dataframe['macdsignal'] = macd_data['macdsignal']
        dataframe['macdhist'] = macd_data['macdhist']
        
        # Crossovers do MACD
        dataframe['macd_cross_above'] = (
            (dataframe['macd'] > dataframe['macdsignal']) &
            (dataframe['macd'].shift(1) <= dataframe['macdsignal'].shift(1))
        )
        dataframe['macd_cross_below'] = (
            (dataframe['macd'] < dataframe['macdsignal']) &
            (dataframe['macd'].shift(1) >= dataframe['macdsignal'].shift(1))
        )
        
        # EMAs para filtro de tendência
        dataframe['ema_short'] = ta.EMA(dataframe, timeperiod=self.ema_short.value)
        dataframe['ema_medium'] = ta.EMA(dataframe, timeperiod=self.ema_medium.value)
        dataframe['ema_long'] = ta.EMA(dataframe, timeperiod=self.ema_long.value)
        
        # Condições de tendência
        dataframe['uptrend'] = (
            (dataframe['ema_short'] > dataframe['ema_medium']) &
            (dataframe['ema_medium'] > dataframe['ema_long']) &
            (dataframe['close'] > dataframe['ema_short'])
        )
        dataframe['downtrend'] = (
            (dataframe['ema_short'] < dataframe['ema_medium']) &
            (dataframe['ema_medium'] < dataframe['ema_long']) &
            (dataframe['close'] < dataframe['ema_short'])
        )
        
        # RSI para filtro adicional
        dataframe['rsi'] = ta.RSI(dataframe, timeperiod=self.rsi_period.value)
        
        # Volume
        dataframe['volume_sma'] = ta.SMA(dataframe['volume'], timeperiod=20)
        dataframe['volume_ratio'] = dataframe['volume'] / dataframe['volume_sma']
        
        # ADX para força da tendência
        dataframe['adx'] = ta.ADX(dataframe, timeperiod=14)
        
        # Bollinger Bands para contexto adicional
        bollinger = ta.BBANDS(dataframe, timeperiod=20, nbdevup=2, nbdevdn=2)
        dataframe['bb_percent'] = (
            (dataframe['close'] - bollinger['lowerband']) / 
            (bollinger['upperband'] - bollinger['lowerband'])
        )
        
        # Stochastic para momentum
        stoch = ta.STOCH(dataframe)
        dataframe['stoch_k'] = stoch['slowk']
        dataframe['stoch_d'] = stoch['slowd']
        
        # ATR para volatilidade
        dataframe['atr'] = ta.ATR(dataframe, timeperiod=14)
        
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Sinais de entrada baseados em MACD e confirmações
        """
        
        conditions = []
        
        # Condição principal: MACD cruzando acima da linha de sinal
        conditions.append(dataframe['macd_cross_above'])
        
        # Filtro de tendência: preço em tendência de alta
        conditions.append(dataframe['uptrend'])
        
        # MACD deve estar em território positivo ou próximo
        conditions.append(dataframe['macd'] > -0.0001)
        
        # Volume confirmando o movimento
        conditions.append(dataframe['volume_ratio'] > self.volume_factor.value)
        
        # RSI não em sobrecompra
        conditions.append(dataframe['rsi'] < self.rsi_buy_max.value)
        
        # ADX mostrando força na tendência
        conditions.append(dataframe['adx'] > 25)
        
        # Bollinger Bands - não comprar em topo extremo
        conditions.append(dataframe['bb_percent'] < 0.85)
        
        # Stochastic confirmando momentum
        conditions.append(
            (dataframe['stoch_k'] > dataframe['stoch_d']) &
            (dataframe['stoch_k'] < 80)
        )
        
        # Confirmação adicional: MACD histogram crescendo
        conditions.append(
            dataframe['macdhist'] > dataframe['macdhist'].shift(1)
        )
        
        # Preço acima da EMA média
        conditions.append(dataframe['close'] > dataframe['ema_medium'])
        
        if conditions:
            dataframe.loc[
                np.logical_and.reduce(conditions),
                'enter_long'
            ] = 1
            
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Sinais de saída baseados em MACD e outros indicadores
        """
        
        conditions = []
        
        # Condição principal: MACD cruzando abaixo da linha de sinal
        conditions.append(dataframe['macd_cross_below'])
        
        # Condições alternativas de saída
        alt_conditions_1 = []
        # RSI em sobrecompra extrema
        alt_conditions_1.append(dataframe['rsi'] > 80)
        alt_conditions_1.append(dataframe['bb_percent'] > 0.95)
        
        alt_conditions_2 = []
        # Quebra da tendência
        alt_conditions_2.append(dataframe['close'] < dataframe['ema_short'])
        alt_conditions_2.append(dataframe['ema_short'] < dataframe['ema_medium'])
        
        alt_conditions_3 = []
        # Stochastic em território de sobrecompra
        alt_conditions_3.append(dataframe['stoch_k'] < dataframe['stoch_d'])
        alt_conditions_3.append(dataframe['stoch_k'] > 80)
        
        # Combinar condições
        main_exit = np.logical_and.reduce(conditions) if conditions else False
        alt_exit_1 = np.logical_and.reduce(alt_conditions_1) if alt_conditions_1 else False
        alt_exit_2 = np.logical_and.reduce(alt_conditions_2) if alt_conditions_2 else False
        alt_exit_3 = np.logical_and.reduce(alt_conditions_3) if alt_conditions_3 else False
        
        final_exit = main_exit | alt_exit_1 | alt_exit_2 | alt_exit_3
        
        dataframe.loc[final_exit, 'exit_long'] = 1
        
        return dataframe

    def confirm_trade_entry(self, pair: str, order_type: str, amount: float,
                          rate: float, time_in_force: str, current_time,
                          entry_tag, side: str, **kwargs) -> bool:
        """
        Confirmação final antes de entrar na posição
        """
        # Pode adicionar verificações adicionais aqui
        # Por exemplo, correlação com outros pares, volatilidade do mercado, etc.
        return True

    def custom_stoploss(self, pair: str, trade, current_time, current_rate, 
                       current_profit, **kwargs):
        """
        Stop loss dinâmico baseado em ATR
        """
        dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last_candle = dataframe.iloc[-1].squeeze()
        
        # Stop loss baseado em ATR
        atr_multiplier = 2.5
        atr_stop = atr_multiplier * last_candle['atr'] / current_rate
        
        # Não pode ser menor que o stop loss fixo
        return max(-atr_stop, self.stoploss)

    def custom_exit(self, pair: str, trade, current_time, current_rate,
                   current_profit, **kwargs):
        """
        Lógica de saída personalizada
        """
        dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last_candle = dataframe.iloc[-1].squeeze()
        
        # Saída rápida se lucro alto e RSI extremo
        if current_profit > 0.15 and last_candle['rsi'] > 85:
            return 'high_profit_extreme_rsi'
        
        # Saída se MACD histogram está diminuindo há 3 candles
        if len(dataframe) >= 3:
            recent_hist = dataframe['macdhist'].tail(3)
            if (recent_hist.iloc[-1] < recent_hist.iloc[-2] < recent_hist.iloc[-3] 
                and current_profit > 0.05):
                return 'macd_histogram_declining'
        
        return None

    def leverage(self, pair: str, current_time, current_rate,
                proposed_leverage: float, max_leverage: float, entry_tag, side: str,
                **kwargs) -> float:
        """
        Alavancagem personalizada por par - 10x para maximizar retornos
        """
        return 10.0  # Alavancagem 10x