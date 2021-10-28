# -*- encoding: UTF-8 -*-
# 實時交易
# CopyRight : XIQICapital 希奇資本
# Author: Kevin Cheng 鄭圳宏
# Create: 2020.02.15
# Update: 2020.02.15
# Version: 1

from __future__ import print_function

from platform import system
if system() == 'Darwin':
    import matplotlib
    matplotlib.use('TkAgg')
# 引入策略類別
from xqctrader.Strategies.PairsCoInWithOU import PairsCoInWithOUStrategy # 統計套利策略
# 引入Redis來連接自建的即時報價
from xqctrader.Events.EventHandler import EventHandler
from xqctrader.Data.HistoricCSVDataHandlerDaily import HistoricCSVDataHandlerDaily # 即時交易的資訊源
from xqctrader.Execution.SimulatedExecutionHandler import SimulatedExecutionHandler # 模擬下單的執行類別
from xqctrader.TradeSession.BacktestDaily import BacktestDaily # 即時交易的主控類別
from xqctrader.Portfolio.PortfolioHFT import PortfolioHFT as Portfolio # 投資組合類別，用來管理部位與資金
from xqctrader.Statistic.TearSheet import TearsheetStatistics # 統計報表類別，用來做交易後的報表產出
from xqctrader.RiskManager.ProfitLoss import ProfitLoss # 計算損益的模組，若觸碰停利停損點則發送PnLEvent

import os
import sys
from queue import Queue
import pandas as pd
import numpy as np
path = os.path.dirname(os.path.abspath(__file__))
if not os.path.isdir(path): path = os.getcwd()
# 用datetime 處理時間
from datetime import datetime, timedelta
import json

def read_symbol_list():
    with open(os.path.join(path, 'StockToFuture.txt'), 'r') as f:
        lines = f.readlines()
        # stock, future
        return lines[0].rstrip().split(','), lines[1].rstrip().split(',')

def read_future_margin():
    with open(os.path.join(path, 'xqctrader', 'Data', 'FutureMarginMap.json'), 'r') as f:
        return json.load(f)['Margin']

def read_data(symbol_list):
    dataPath = os.path.join(path, 'historicalDailyKline')
    df = pd.DataFrame()
    min_daterange = None
    for f in os.listdir(dataPath):
        ticker = f.split('_')[0]
        if ticker in symbol_list:
            temp = pd.read_csv(os.path.join(dataPath, f), encoding='utf-8-sig', sep=',')
            temp['Ticker'] = ticker
            if df.empty:
                df = temp
            else:
                df = df.append(temp)
            if min_daterange is None:
                min_daterange = temp['date']
            elif temp.shape[0] < len(min_daterange):
                min_daterange = temp['date']
    df = df[df['date'].isin(min_daterange)]
    df['date'] = pd.to_datetime(df['date'])
    df = df.loc[:,'date,Ticker,open,high,low,close,volume'.split(',')]
    df.columns = 'Date,Ticker,open,high,low,close,volume'.split(',')
    return df

# realtime main program sample
if __name__ == "__main__":
    stock_list, future_list = read_symbol_list() # 從檔案取得商品清單
    margin_multiplier = read_future_margin()
    symbol_list = stock_list + future_list # 將股票清單與期貨清單加入到商品清單中
    
    point_multiplier = dict((k,v) for k, v in [(s, 1000) for s in stock_list]) # 每隻標的價格乘數，用以還原成現金計算資產
    point_multiplier.update(dict((k,v) for k, v in [(s, 2000) for s in future_list])) # 每隻標的價格乘數，用以還原成現金計算資產
    point_multiplier['OLF00'] = 100
    
    exchanges = dict((k,v) for k, v in [(s, 'TSE') for s in stock_list]) # 股票標的所在之交易所，用以計算commission
    exchanges.update(dict((k,v) for k, v in [(s, 'TFE') for s in future_list])) # 期貨標的所在之交易所，用以計算commission
    
    type_dict = dict((k,v) for k, v in [(s, 'STOCK') for s in stock_list]) # 股票標的所在之交易所，用以計算commission
    type_dict.update(dict((k,v) for k, v in [(s, 'FUTURE') for s in future_list])) # 期貨標的所在之交易所，用以計算commission
    
    stock_to_future = {}
    count_3008 = 0
    for i in range(len(stock_list)):
        stock_to_future[stock_list[i]] = future_list[i] # 配對的mapping，股票對期貨

    periods = 252 # 用來做最後報表的統計結果計算
    
    # Initialize EventHandler
    eventmanager = Queue()

    # Initialize DataHandler
    data = read_data(symbol_list)
    start_date = min(data.index)
    datahandler = HistoricCSVDataHandlerDaily(eventmanager, symbol_list, start_date, data=data)
    
    # Initialize strategy
    # 策略的參數設定
    strat_param_dict = dict(stockToFuture_map=stock_to_future,
                            lookback=120, exit_threshold=0.5, entry_threshold=2.0)
    strategy = PairsCoInWithOUStrategy(datahandler, eventmanager, point_multiplier, type_dict, **strat_param_dict)
    
    # Initialize Portfolio
    account_balance = {'Capital':10000000.0, 'Margin':10000000.0} # 模擬交易之初始資金
    portfolio = Portfolio(datahandler, eventmanager, point_multiplier, start_date, account_balance, margin_multiplier=margin_multiplier, type_dict=type_dict)
    
    # Initialize Profitloss
    takeprofit = 0.02 # 固定停利得點位
    stop_loss = 0.01 # 固定停損的點位
    dynamic_threshold = 0.02 # 動態停利的啟動門檻
    adj_takeprofit = 0.01 # 每次突破動態停利點後的調整項
    profitloss = ProfitLoss(takeprofit, stop_loss, eventmanager, symbol_list, 
                            dynamic_threshold=dynamic_threshold, 
                            adj_takeprofit=adj_takeprofit, Dynamic=True)
    
    # Initialize ExecutionHandler
    execution_handler = SimulatedExecutionHandler(eventmanager, exchanges, point_multiplier)
    
    # Initialize Statistic module
    statistic = TearsheetStatistics(portfolio, datahandler, eventmanager, title='simulate BackTest trading', periods=periods)

    # Initialize RealTimeTrade
    backtest = BacktestDaily(eventmanager, symbol_list, account_balance, point_multiplier, start_date,
                            datahandler, execution_handler, portfolio, strategy, profitloss, 
                            statistic, periods=periods, strat_param_dict=strat_param_dict)
    
    # Start Trade
    backtest.simulate_trading()