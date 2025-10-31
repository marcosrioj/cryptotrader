# RSI + Bollinger Bands Strategy
# Uma das estratégias mais populares no FreqTrade
# Combina RSI para momentum e Bollinger Bands para volatilidade

import talib.abstract as ta
from freqtrade.strategy import IStrategy, DecimalParameter, IntParameter
from pandas import DataFrame
import numpy as np


class RSIBBStrategy(IStrategy):
    """
    Estratégia RSI + Bollinger Bands
    
    Esta estratégia combina:
    - RSI (Relative Strength Index) para identificar condições de sobrecompra/sobrevenda
    - Bollinger Bands para identificar níveis de suporte e resistência
    - Volume para confirmar sinais
    
    Sinais de compra:
    - RSI < 30 (sobrevenda)
    - Preço toca a banda inferior do Bollinger
    - Volume acima da média
    
    Sinais de venda:
    - RSI > 70 (sobrecompra)
    - Preço toca a banda superior do Bollinger
    - Ou stop loss/take profit
    """

    # Configurações básicas da estratégia
    INTERFACE_VERSION = 3
    
    # Configurações de risco
    stoploss = -0.05  # Stop loss de 5%
    
    # Configurações de timeframe
    timeframe = '1h'
    
    # Configurações de trailing stop
    trailing_stop = True
    trailing_stop_positive = 0.01
    trailing_stop_positive_offset = 0.02
    trailing_only_offset_is_reached = True
    
    # Configurações de ROI (Return on Investment)
    minimal_roi = {
        "0": 0.15,    # 15% após 0 minutos
        "60": 0.10,   # 10% após 60 minutos
        "120": 0.05,  # 5% após 120 minutos
        "180": 0.02   # 2% após 180 minutos
    }
    
    # Parâmetros otimizáveis
    rsi_period = IntParameter(10, 20, default=14, space="buy")
    rsi_buy_threshold = IntParameter(25, 35, default=30, space="buy")
    rsi_sell_threshold = IntParameter(65, 75, default=70, space="sell")
    
    bb_period = IntParameter(15, 25, default=20, space="buy")
    bb_std = DecimalParameter(1.5, 2.5, default=2.0, space="buy")
    
    volume_factor = DecimalParameter(1.0, 2.0, default=1.5, space="buy")
    
    # Configurações de proteção
    use_exit_signal = True
    exit_profit_only = False
    ignore_roi_if_entry_signal = False
    
    # Configurações para não comprar durante tendências de baixa
    startup_candle_count: int = 30

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Adiciona indicadores técnicos ao dataframe
        """
        
        # RSI (Relative Strength Index)
        dataframe['rsi'] = ta.RSI(dataframe, timeperiod=self.rsi_period.value)
        
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
        dataframe['bb_percent'] = (dataframe['close'] - dataframe['bb_lowerband']) / (dataframe['bb_upperband'] - dataframe['bb_lowerband'])
        dataframe['bb_width'] = (dataframe['bb_upperband'] - dataframe['bb_lowerband']) / dataframe['bb_middleband']
        
        # Volume
        dataframe['volume_sma'] = ta.SMA(dataframe['volume'], timeperiod=20)
        
        # Médias móveis para filtro de tendência
        dataframe['ema_short'] = ta.EMA(dataframe, timeperiod=9)
        dataframe['ema_long'] = ta.EMA(dataframe, timeperiod=21)
        
        # MACD para confirmação
        macd = ta.MACD(dataframe)
        dataframe['macd'] = macd['macd']
        dataframe['macdsignal'] = macd['macdsignal']
        dataframe['macdhist'] = macd['macdhist']
        
        # ADX para força da tendência
        dataframe['adx'] = ta.ADX(dataframe)
        
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Baseado nos indicadores TA, popula a coluna 'enter_long' para indicar sinais de compra
        """
        
        conditions = []
        
        # Condição principal: RSI em sobrevenda
        conditions.append(dataframe['rsi'] < self.rsi_buy_threshold.value)
        
        # Preço próximo ou abaixo da banda inferior do Bollinger
        conditions.append(
            (dataframe['close'] <= dataframe['bb_lowerband'] * 1.02) |
            (dataframe['bb_percent'] < 0.1)
        )
        
        # Volume acima da média
        conditions.append(dataframe['volume'] > (dataframe['volume_sma'] * self.volume_factor.value))
        
        # Filtro de tendência: EMA curta acima da longa (opcional, descomente para usar)
        # conditions.append(dataframe['ema_short'] > dataframe['ema_long'])
        
        # MACD em território positivo ou cruzando para cima
        conditions.append(
            (dataframe['macd'] > dataframe['macdsignal']) |
            (dataframe['macdhist'] > 0)
        )
        
        # ADX mostra força da tendência
        conditions.append(dataframe['adx'] > 20)
        
        # Volatilidade adequada (Bollinger Bands não muito estreitas)
        conditions.append(dataframe['bb_width'] > 0.02)
        
        # Combinar todas as condições
        if conditions:
            dataframe.loc[
                np.logical_and.reduce(conditions),
                'enter_long'
            ] = 1
            
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Baseado nos indicadores TA, popula a coluna 'exit_long' para indicar sinais de venda
        """
        
        conditions = []
        
        # Condição principal: RSI em sobrecompra
        conditions.append(dataframe['rsi'] > self.rsi_sell_threshold.value)
        
        # Preço próximo ou acima da banda superior do Bollinger
        conditions.append(
            (dataframe['close'] >= dataframe['bb_upperband'] * 0.98) |
            (dataframe['bb_percent'] > 0.9)
        )
        
        # Alternativa: MACD cruzando para baixo
        alt_conditions = []
        alt_conditions.append(dataframe['macd'] < dataframe['macdsignal'])
        alt_conditions.append(dataframe['macdhist'] < 0)
        
        # Sair se RSI + BB ou se MACD confirma saída
        final_condition = (
            np.logical_and.reduce(conditions) |
            np.logical_and.reduce(alt_conditions)
        )
        
        dataframe.loc[final_condition, 'exit_long'] = 1
        
        return dataframe

    def confirm_trade_entry(self, pair: str, order_type: str, amount: float,
                          rate: float, time_in_force: str, current_time,
                          entry_tag, side: str, **kwargs) -> bool:
        """
        Confirmação adicional antes de entrar em uma posição
        """
        # Aqui você pode adicionar lógica adicional de confirmação
        # Por exemplo, verificar notícias, outros pares, etc.
        return True

    def custom_stoploss(self, pair: str, trade, current_time, current_rate, current_profit, **kwargs):
        """
        Stop loss personalizado baseado em ATR ou outros indicadores
        """
        # Implementar stop loss baseado em volatilidade se desejar
        return None

    def leverage(self, pair: str, current_time, current_rate,
                proposed_leverage: float, max_leverage: float, entry_tag, side: str,
                **kwargs) -> float:
        """
        Customizar alavancagem por par - 10x para maximizar retornos
        """
        return 10.0  # Alavancagem 10x