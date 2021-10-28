# -*- encoding: UTF-8 -*-
# 實時交易
# CopyRight : XIQICapital 希奇資本
# Author: Kevin Cheng 鄭圳宏
# Create: 2020.03.15
# Update: 2020.04.25
# Version: 1

from __future__ import print_function

from platform import system
if system() == 'Darwin':
    import matplotlib
    matplotlib.use('TkAgg')
# 引入策略類別
from xqctrader.Strategies.ThreeThresholdStrategy import ThreeThresholdStrategy as Strategy# 統計套利策略
# 引入Redis來連接自建的即時報價
#from xqctrader.Events.EventHandler import EventHandler
from xqctrader.Data.HistoricCSVDataHandler import HistoricCSVDataHandler as DataHandler # 即時交易的資訊源
from xqctrader.Execution.SimulatedExecutionHandler import SimulatedExecutionHandler as ExecutionHandler # 模擬下單的執行類別
from xqctrader.TradeSession.Backtest import Backtest as BackTest # 即時交易的主控類別
from xqctrader.Portfolio.PortfolioHFT import PortfolioHFT as Portfolio # 投資組合類別，用來管理部位與資金
from xqctrader.Statistic.TearSheet import TearsheetStatistics # 統計報表類別，用來做交易後的報表產出
from xqctrader.RiskManager.ProfitLoss import ProfitLoss # 計算損益的模組，若觸碰停利停損點則發送PnLEvent
from xqctrader.Messenger.LineMessenger import LineMessenger as Line
from xqctrader.Status.StatusValue import DataFreq, TradeStatus

import os, sys, json, time
from queue import Queue
import pandas as pd
import numpy as np
path = os.path.dirname(os.path.abspath(__file__))
if not os.path.isdir(path): path = os.getcwd()
parent = os.path.dirname(os.path.dirname(path)) # in realtime_trading
datapath = os.path.join(parent, 'realtime_trading', 'daily_information', 'futuredaily')
klinepath = os.path.join(parent, 'realtime_trading', 'daily_information', 'futurekline')
# 用datetime 處理時間
from datetime import datetime, timedelta
from multiprocessing.pool import ThreadPool as Pool

def read_symbol_list():
    with open(os.path.join(path, 'FutureStockList.txt'), 'r') as f:
        lines = f.readlines()
        return lines[4].rstrip().split(','), lines[5].rstrip().split(',')

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
        if df.empty:
            df = temp[temp.code.isin(symbol_list)]
        else:
            df = df.append(temp[temp.code.isin(symbol_list)])
    df = df.loc[:,'tradingdate,code,maturity,tradingtime,price,volume'.split(',')]
    del df['maturity']
    df.columns = 'Date,Ticker,Time,close,volume'.split(',')
    df.index = range(df.shape[0])
    return df

def read_kline_csv(symbol_list, days):
    listdir = sorted([f for f in os.listdir(klinepath) if '.csv' in f])
    listfile = listdir[-days:]
    df = pd.DataFrame()
    for f in listfile:
        temp = pd.read_csv(os.path.join(klinepath, f), encoding='utf-8', sep=',', low_memory=False)
        temp.Time = temp.Time.apply(float)
        temp.Ticker += '00'
        temp = temp[temp.Ticker.isin(symbol_list)]
        ttm = sorted([x for x in temp.loc[:, 'Maturity'].apply(str).unique() if ('/' not in x) and ('W' not in x)])[0]
        temp = temp[(84500 <= temp.loc[:, 'Time']) & (temp.loc[:, 'Time'] <= 134500) & (temp.loc[:, 'Maturity'] == ttm)]
        if df.empty:
            df = temp
        else:
            df = df.append(temp)
    df = df.loc[:,'Date,Ticker,Time,Maturity,Open,High,Low,Close,Volume'.split(',')]
    del df['Maturity']
    df.columns = 'Date,Ticker,Time,open,high,low,close,volume'.split(',')
    df.index = range(df.shape[0])
    return df # [df['Ticker'].isin(symbol_list)].reset_index()

def read_future_margin():
    with open(os.path.join(path, 'xqctrader', 'Data', 'Multipliers', 'FutureMarginMap.json'), 'r') as f:
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

def runBacktest(symbol, data, days):
    symbol_list = [symbol]
    point_multiplier = dict((k,v) for k, v in [(s, 2000) for s in symbol_list]) # 每隻標的價格乘數，用以還原成現金計算資產
    point_multiplier['TX00'] = 200
    point_multiplier['TE00'] = 200
    point_multiplier['TF00'] = 200
    point_multiplier['OLF00'] = 100
    exchanges = dict((k,v) for k, v in [(s, 'TFE') for s in symbol_list]) # 期貨標的所在之交易所，用以計算commission
    type_dict = dict((k,v) for k, v in [(s, 'FUTURE') for s in symbol_list]) # 期貨標的所在之交易所，用以計算commission
    margin_multiplier = read_future_margin() # 期貨標的所在之交易所，用以計算commission
    
    #days = 20
    start_time, end_time = 84500, 133000
    periods = int(round(252 * 5 * 60 * 60 / days)) # 用來做最後報表的統計結果計算
    
    # Initialize EventHandler
    eventmanager = Queue()

    # Initialize DataHandler
    #startRead = time.time()
    data = read_csv(symbol_list, days)
    if data.empty: return
    #data = read_kline_csv(symbol_list, days)
    #readDur = time.time() - startRead
    #Line.sendMessage(f'Read {days} file, using {readDur} seconds.')
    start_date = min(data.Date)
    datahandler = DataHandler(eventmanager, data, symbol_list)

    # Initialize strategy
    # 策略的參數設定
    estimation_interval = [84500, 91500]
    strategy = Strategy(datahandler, eventmanager, point_multiplier, type_dict, start_end=[start_time, end_time], estimation_interval=estimation_interval, dataFreq=DataFreq.Intraday, tradeStatus=TradeStatus.BacktestIntraday, Real=False)
    
    # Initialize Portfolio
    account_balance = {'Capital':10000000.0, 'Margin':10000000.0} # 模擬交易之初始資金
    portfolio = Portfolio(datahandler, eventmanager, point_multiplier, start_date, account_balance, type_dict=type_dict, margin_multiplier=margin_multiplier, Real=False)
    
    # Initialize Profitloss
    stop_loss = 0.1 # 2000 / sum(account_balance.values())
    takeprofit = stop_loss * 2.5 # 0.005 # 固定停利得點位
    #stop_loss = 0.002 # 固定停損的點位
    dynamic_threshold = stop_loss * 1.5 # 0.003 # 動態停利的啟動門檻
    adj_takeprofit = stop_loss / 2 # 0.001 # 每次突破動態停利點後的調整項
    profitloss = ProfitLoss(takeprofit, stop_loss, eventmanager, symbol_list, 
                            dynamic_threshold=dynamic_threshold, 
                            adj_takeprofit=adj_takeprofit, Dynamic=True)
    
    # Initialize ExecutionHandler
    execution_handler = ExecutionHandler(eventmanager, exchanges, point_multiplier)
    
    # Initialize Statistic module
    statistic = TearsheetStatistics(portfolio, datahandler, eventmanager, title=f'simulate BackTest trading of {str(strategy)} with {symbol_list[0]}', 
                                    periods=periods, benchmark=symbol_list[0], aggregateToDaily=True if days > 1 else False, tradeStatus=TradeStatus.BacktestIntraday)

    # Initialize RealTimeTrade
    backtest = BackTest(eventmanager, symbol_list, start_date, 
                        start_time, end_time, datahandler, execution_handler, portfolio, strategy, 
                        profitloss, statistic, periods=periods, ndays=days)
    
    # Start Trade
    startTrade = time.time()
    backtest.simulate_trading()
    tradeDur = time.time() - startTrade
    Line.sendMessage(f'Backest with {days} day(s) kbar/tick, using {tradeDur} seconds.')

# realtime main program sample
if __name__ == "__main__":
    """stock_list, future_list = read_symbol_list() # 從檔案取得商品清單
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
        stock_to_future[stock_list[i]] = future_list[i] # 配對的mapping，股票對期貨"""
    stock_list, future_list = read_symbol_list() # 從檔案取得商品清單
    #future_list += ['TX00', 'MTX00', 'TE00', 'TF00']
    #future_list = ['TX00']
    days = 10
    data = read_csv(future_list, days)
    #pool = Pool(8)
    start_time = time.time()
    #result = [pool.apply_async(runBacktest, args=(s,data[data['Ticker']==s])) for s in future_list]
    #final = [f.get() for f in result]
    for s in future_list: runBacktest(s, data[data['Ticker']==s], days)
    duration = time.time() - start_time
    Line.sendMessage(f'run {len(future_list)} future, used {round(duration/3600, 4)} hours')
