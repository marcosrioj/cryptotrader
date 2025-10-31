# EMA Crossover Scalping Strategy
# Fast scalping strategy based on EMA crossovers
# Optimized for 1m and 5m timeframes

import talib.abstract as ta
from freqtrade.strategy import IStrategy, DecimalParameter, IntParameter
from pandas import DataFrame
import numpy as np
import pandas as pd
from datetime import timedelta


class EMAScalpingStrategy(IStrategy):
    """
    EMA Crossover Scalping Strategy
    
    This strategy uses:
    - Fast EMAs (5, 10, 21) for entry/exit signals
    - RSI to avoid extremes
    - Volume for confirmation
    - Tight stop loss for scalping
    
    Buy signals:
    - EMA 5 crosses above EMA 10
    - EMA 10 above EMA 21 (uptrend)
    - RSI between 30-70 (not at extremes)
    - Volume above average
    
    Sell signals:
    - EMA 5 crosses below EMA 10
    - Or RSI > 75
    - Or stop loss/take profit
    """

    # Basic strategy configuration
    INTERFACE_VERSION = 3
    
    # Risk settings for scalping
    stoploss = -0.02  # 2% stop loss (tight for scalping)
    
    # Timeframe settings
    timeframe = '1m'  # 1-minute scalping
    
    # Trailing stop configuration
    trailing_stop = True
    trailing_stop_positive = 0.005  # 0.5%
    trailing_stop_positive_offset = 0.01  # 1%
    trailing_only_offset_is_reached = True
    
    # Aggressive ROI for scalping
    minimal_roi = {
        "0": 0.03,    # 3% immediate
        "3": 0.02,    # 2% after 3 minutes
        "5": 0.015,   # 1.5% after 5 minutes
        "10": 0.01,   # 1% after 10 minutes
        "15": 0.005   # 0.5% after 15 minutes
    }
    
    # Optimizable parameters
    ema_fast = IntParameter(3, 8, default=5, space="buy")
    ema_medium = IntParameter(8, 15, default=10, space="buy")
    ema_slow = IntParameter(18, 25, default=21, space="buy")
    
    rsi_period = IntParameter(10, 16, default=14, space="buy")
    rsi_buy_min = IntParameter(25, 35, default=30, space="buy")
    rsi_buy_max = IntParameter(65, 75, default=70, space="buy")
    rsi_sell_threshold = IntParameter(70, 80, default=75, space="sell")
    
    volume_factor = DecimalParameter(1.2, 2.0, default=1.5, space="buy")
    
    # Protection settings
    use_exit_signal = True
    exit_profit_only = False
    ignore_roi_if_entry_signal = False
    
    startup_candle_count: int = 30

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Add technical indicators to dataframe
        """
        
        # EMAs for crossover
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
        
        # Trend
        dataframe['uptrend'] = dataframe['ema_medium'] > dataframe['ema_slow']
        dataframe['downtrend'] = dataframe['ema_medium'] < dataframe['ema_slow']
        
        # RSI
        dataframe['rsi'] = ta.RSI(dataframe, timeperiod=self.rsi_period.value)
        
        # Volume
        dataframe['volume_sma'] = ta.SMA(dataframe['volume'], timeperiod=10)
        dataframe['volume_ratio'] = dataframe['volume'] / dataframe['volume_sma']
        
        # MACD for additional confirmation
        macd = ta.MACD(dataframe, fastperiod=12, slowperiod=26, signalperiod=9)
        dataframe['macd'] = macd['macd']
        dataframe['macdsignal'] = macd['macdsignal']
        dataframe['macdhist'] = macd['macdhist']
        
        # Bollinger Bands for volatility
        bollinger = ta.BBANDS(dataframe, timeperiod=20, nbdevup=2, nbdevdn=2)
        dataframe['bb_lowerband'] = bollinger['lowerband']
        dataframe['bb_upperband'] = bollinger['upperband']
        dataframe['bb_width'] = (bollinger['upperband'] - bollinger['lowerband']) / dataframe['close']
        
        # ATR for volatility
        dataframe['atr'] = ta.ATR(dataframe, timeperiod=14)
        
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Entry signals for scalping
        """
        
        conditions = []
        
        # Main condition: EMA crossover upward
        conditions.append(dataframe['ema_cross_up'])
        
        # Uptrend
        conditions.append(dataframe['uptrend'])
        
        # RSI in neutral zone (not overbought/oversold)
        conditions.append(dataframe['rsi'] >= self.rsi_buy_min.value)
        conditions.append(dataframe['rsi'] <= self.rsi_buy_max.value)
        
        # Volume confirmation
        conditions.append(dataframe['volume_ratio'] > self.volume_factor.value)
        
        # MACD positive momentum
        conditions.append(dataframe['macdhist'] > 0)
        
        # Adequate volatility for scalping
        conditions.append(dataframe['bb_width'] > 0.015)
        
        # Price above slow EMA
        conditions.append(dataframe['close'] > dataframe['ema_slow'])
        
        if conditions:
            dataframe.loc[
                np.logical_and.reduce(conditions),
                'enter_long'
            ] = 1
            
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Exit signals for scalping
        """
        
        conditions = []
        
        # Main condition: EMA crossover downward
        conditions.append(dataframe['ema_cross_down'])
        
        # Alternative conditions
        alt_conditions = []
        
        # RSI overbought
        alt_conditions.append(dataframe['rsi'] > self.rsi_sell_threshold.value)
        
        # MACD losing momentum
        alt_conditions.append(
            (dataframe['macd'] < dataframe['macdsignal']) &
            (dataframe['macdhist'] < dataframe['macdhist'].shift(1))
        )
        
        # Trend break
        alt_conditions.append(dataframe['downtrend'])
        
        # Combine conditions
        main_exit = np.logical_and.reduce(conditions) if conditions else False
        alt_exit = np.logical_or.reduce(alt_conditions) if alt_conditions else False
        
        dataframe.loc[main_exit | alt_exit, 'exit_long'] = 1
        
        return dataframe

    def custom_stoploss(self, pair: str, trade, current_time, current_rate, 
                       current_profit, **kwargs):
        """
        Dynamic stop loss based on ATR for scalping
        """
        dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last_candle = dataframe.iloc[-1].squeeze()
        
        # Stop loss based on ATR (tighter for scalping)
        atr_multiplier = 1.5
        atr_stop = atr_multiplier * last_candle['atr'] / current_rate
        
        # Cannot be smaller than fixed stop loss
        return max(-atr_stop, self.stoploss)

    def custom_exit(self, pair: str, trade, current_time, current_rate,
                   current_profit, **kwargs):
        """
        Custom exits for scalping
        """
        dataframe, _ = self.dp.get_analyzed_dataframe(pair, self.timeframe)
        last_candle = dataframe.iloc[-1].squeeze()
        
        # Quick exit if high profit in short time
        if current_profit > 0.02 and (current_time - trade.open_date_utc.replace(tzinfo=None)).total_seconds() < 120:
            return 'quick_profit_scalp'
        
        # Exit if RSI extreme and positive profit
        if current_profit > 0.005 and last_candle['rsi'] > 80:
            return 'rsi_extreme_exit'
        
        return None

    def leverage(self, pair: str, current_time, current_rate,
                proposed_leverage: float, max_leverage: float, entry_tag, side: str,
                **kwargs) -> float:
        """
        Leverage for scalping
        """
        return 10.0  # 10x leverage (configure manually on Bybit)