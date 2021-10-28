# -*- encoding: UTF-8 -*-
# 實時交易 - OLS配對交易
# CopyRight : XIQICapital 希奇資本
# Author: Kevin Cheng 鄭圳宏
# Create: 2020.04.21
# Update: 2020.04.22
# Version: 1

from __future__ import print_function

from platform import system
if system() == 'Darwin':
    import matplotlib
    matplotlib.use('TkAgg')
# 引入策略類別
from xqctrader.Strategies.IntradayOLSMRStrategy import IntradayOLSMRStrategy as Strategy # 期現貨套利
# 引入Redis來連接自建的即時報價
from xqctrader.Data.HistoricCSVDataHandler import HistoricCSVDataHandler as DataHandler # 即時交易的資訊源
from xqctrader.Execution.SimulatedExecutionHandler import SimulatedExecutionHandler # 模擬下單的執行類別
from xqctrader.TradeSession.Backtest import Backtest as BackTest # 即時交易的主控類別
from xqctrader.Portfolio.PortfolioHFT import PortfolioHFT as Portfolio # 投資組合類別，用來管理部位與資金
from xqctrader.Statistic.TearSheet import TearsheetStatistics # 統計報表類別，用來做交易後的報表產出
from xqctrader.RiskManager.ProfitLoss import ProfitLoss # 計算損益的模組，若觸碰停利停損點則發送PnLEvent
from xqctrader.Messenger.LineMessenger import LineMessenger as Line
from xqctrader.Status.StatusValue import TradeStatus, DataFreq

import os, sys, json, time
from queue import Queue
path = os.path.dirname(os.path.abspath(__file__))
if not os.path.isdir(path): path = os.getcwd()
parent = os.path.dirname(os.path.dirname(path)) # in realtime_trading
datapath = os.path.join(parent, 'realtime_trading', 'daily_information', 'futuredaily')
klinePath = os.path.join(parent, 'realtime_trading', 'daily_information', 'future1minK') # 
# 用datetime 處理時間
from datetime import datetime, timedelta
import pandas as pd

def read_future_margin():
    with open(os.path.join(path, 'xqctrader', 'Data', 'FutureMarginMap.json'), 'r') as f:
        return json.load(f)['Margin']

def read_csv(symbol_list, days):
    listdir = sorted([f for f in os.listdir(datapath) if '.csv' in f])
    listfile = listdir[-days:]
    df = pd.DataFrame()
    for f in listfile:
        temp = pd.read_csv(os.path.join(datapath, f), encoding='utf-8', sep=',', index_col=0, low_memory=False)
        temp.tradingtime = temp.tradingtime.apply(float)
        temp.code += '00'
        temp = temp[temp.code.isin(symbol_list)]
        try:
            ttm = sorted([x for x in temp.loc[:, 'maturity'].apply(str).unique() if ('/' not in x) and ('W' not in x)])[0]
        except:
            continue
        temp = temp[(84500 <= temp.loc[:, 'tradingtime']) & (temp.loc[:, 'tradingtime'] <= 134500) & (temp.loc[:, 'maturity'] == ttm)]
        df = temp[temp.code.isin(symbol_list)] if df.empty else df.append(temp[temp.code.isin(symbol_list)])
    df = df.loc[:,'tradingdate,code,maturity,tradingtime,price,volume'.split(',')]
    del df['maturity']
    df.columns = 'Date,Ticker,Time,close,volume'.split(',')
    df.index = range(df.shape[0])
    return df

def read_kline_csv(symbol_list, days):
    listdir = sorted([f for f in os.listdir(klinePath) if '.csv' in f])
    listfile = listdir[-days:]
    df = pd.DataFrame()
    for f in listfile:
        temp = pd.read_csv(os.path.join(klinePath, f), encoding='utf-8', sep=',', low_memory=False)
        temp.Time = temp.Time.apply(float)
        temp.Ticker += '00'
        temp = temp[temp.Ticker.isin(symbol_list)]
        try:
            ttm = sorted([x for x in temp.loc[:, 'Maturity'].apply(str).unique() if ('/' not in x) and ('W' not in x)])[0]
        except:
            continue
        temp = temp[(84500 <= temp.loc[:, 'Time']) & (temp.loc[:, 'Time'] <= 134500) & (temp.loc[:, 'Maturity'] == ttm)]
        df = temp[temp.Ticker.isin(symbol_list)] if df.empty else df.append(temp[temp.Ticker.isin(symbol_list)])
    df = df.loc[:,'Date,Time,Ticker,Maturity,Open,High,Low,Close,Volume'.split(',')]
    del df['Maturity']
    df.index = range(df.shape[0])
    df.columns = 'Date,Time,Ticker,open,high,low,close,volume'.split(',')
    return df

def main(p0,p1):
    p0_list = [p0]#['CDF00']#
    p1_list = [p1]#['DHF00']#
    symbol_list = p0_list + p1_list # 將股票清單與期貨清單加入到商品清單中
    point_multiplier = dict((k,v) for k, v in [(s, 2000) for s in symbol_list])
    point_multiplier.update({'TX00':200, 'TE00':4000, 'TF00':1000, 'MTX00':50})
    type_dict = dict((k,v) for k, v in [(s, 'FUTURE') for s in symbol_list])
    exchanges = dict((k,v) for k, v in [(s, "TFE") for s in symbol_list])
    pairs_map = {'p0_to_p1':{}, 'p1_to_p0':{}}
    for i, p0 in enumerate(p0_list):
        pairs_map['p0_to_p1'].update({p0:p1_list[i]})
        pairs_map['p1_to_p0'].update({p1_list[i]:p0})
    
    days = 252
    start_time, end_time = 84500, 133000
    periods = int(round(252 * 5 * 60 / days)) # 用來做最後報表的統計結果計算

    # Initialize EventHandler
    eventmanager = Queue()

    # Initialize DataHandler
    #data = read_csv(symbol_list, days)
    data = read_kline_csv(symbol_list, days)
    if data.empty: return
    start_date = min(data.Date)
    datahandler = DataHandler(eventmanager, data, symbol_list, pairs_map)
    
    # Initialize strategy
    # 策略的參數設定
    strat_param_dict = dict(zscore_low=0.5, zscore_high=3.0, ols_window=100)
    strategy = Strategy(datahandler, eventmanager, pairs_map, point_multiplier, type_dict, dataFreq = DataFreq.Intraday, tradeStatus=TradeStatus.BacktestIntraday, start_end=[start_time, end_time], Real=False, **strat_param_dict)
    
    # Initialize Portfolio
    account_balance = {'Capital':10000000.0, 'Margin':10000000.0}
    portfolio = Portfolio(datahandler, eventmanager, point_multiplier, start_date, account_balance, Real=False, start_end=[start_time, end_time], pairs_map=pairs_map, type_dict=type_dict)
    
    # Initialize Profitloss
    stop_loss = 6000 / sum(account_balance.values())
    takeprofit = stop_loss * 2.5 # 0.005 # 固定停利得點位
    #stop_loss = 0.002 # 固定停損的點位
    dynamic_threshold = stop_loss * 1.5 # 0.003 # 動態停利的啟動門檻
    adj_takeprofit = stop_loss / 2 # 0.001 # 每次突破動態停利點後的調整項
    profitloss = ProfitLoss(takeprofit, stop_loss, eventmanager, symbol_list, 
                            dynamic_threshold=dynamic_threshold, 
                            adj_takeprofit=adj_takeprofit, Dynamic=True)
    
    # Initialize ExecutionHandler
    execution_handler = SimulatedExecutionHandler(eventmanager, exchanges, point_multiplier)
    
    # Initialize Statistic module
    title = f'simulate BackTest trading of {str(strategy)} with {symbol_list[0]}'
    statistic = TearsheetStatistics(portfolio, datahandler, eventmanager, title=title, periods=periods, aggregateToDaily=True, tradeStatus=TradeStatus.BacktestIntraday)

    # Initialize RealTimeTrade
    backtest = BackTest(eventmanager, symbol_list, start_date, start_time, end_time, 
                        datahandler, execution_handler, portfolio, strategy, profitloss, 
                        statistic, periods=periods, strat_param_dict=strat_param_dict)

    start_time = time.time()
    # Start Trade
    backtest.simulate_trading()
    duration = round((time.time() - start_time)/60, 4)
    from xqctrader.Messenger.LineMessenger import LineMessenger as Line
    Line.sendMessage(f'Backtest for {str(strategy)} for {days} use {",".join(symbol_list)} cost {duration} mins.')

# realtime main program sample
if __name__ == "__main__":
    for (p0, p1) in [('CJF00', 'DNF00'),('LXF00', 'CMF00'),('CCF00', 'OLF00'),('CCF00', 'DNF00'),('CEF00','CMF00')]:
        main(p0, p1)