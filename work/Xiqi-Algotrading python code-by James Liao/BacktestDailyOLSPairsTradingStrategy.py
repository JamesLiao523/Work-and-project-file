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
from xqctrader.TradeSession.Redis_event import Redis
from xqctrader.Data.HistoricCSVDataHandlerDaily import HistoricCSVDataHandlerDaily as DataHandler # 即時交易的資訊源
from xqctrader.Execution.SimulatedExecutionHandler import SimulatedExecutionHandler # 模擬下單的執行類別
from xqctrader.TradeSession.BacktestDaily import BacktestDaily as BackTest # 即時交易的主控類別
from xqctrader.Portfolio.PortfolioHFT import PortfolioHFT as Portfolio # 投資組合類別，用來管理部位與資金
from xqctrader.Statistic.TearSheet import TearsheetStatistics # 統計報表類別，用來做交易後的報表產出
from xqctrader.RiskManager.ProfitLoss import ProfitLoss # 計算損益的模組，若觸碰停利停損點則發送PnLEvent
from xqctrader.Messenger.LineMessenger import LineMessenger as Line
from xqctrader.Status.StatusValue import TradeStatus, DataFreq
from itertools import product, combinations
from xqctrader.Data.GetDataFromApi import get_df_from_web_api

import os, sys, json, time
from queue import Queue
path = os.path.dirname(os.path.abspath(__file__))
if not os.path.isdir(path): path = os.getcwd()
# 用datetime 處理時間
from datetime import datetime, timedelta
import numpy as np
import pandas as pd
pd.set_option("display.max_rows", None, "display.max_columns", None)
import statsmodels.api as sm
from pykalman import KalmanFilter
from itertools import combinations
from multiprocessing.pool import ThreadPool as Pool

### Calculate ConIntegration to get Pairs
def CoIntegration(df, critical_level = 0.05):
    cols = list(df.columns)
    cols.remove('index')
    pvalue_matrix = pd.DataFrame(index=cols, columns=cols)
    #pvalue_matrix = np.ones((df.shape[1], df.shape[1]))
    pairs = []
    for (key1, key2) in list(combinations(cols, 2)):
    #for i, key1 in enumerate(keys):
    #    for j, key2 in enumerate(keys[i+1:]):
        s1 = df[key1]; s2 = df[key2]
        result = sm.tsa.stattools.coint(s1, s2)
        pvalue = result[1]
        pvalue_matrix.loc[key2, key1] = pvalue_matrix.loc[key1, key2] = pvalue
        if pvalue < critical_level:
            pairs.append((key1, key2, pvalue))
    return pvalue_matrix, pairs

def kalmanfilterAverage(x):
    kf = KalmanFilter(
        transition_matrices=[1],
        observation_matrices=[1],
        initial_state_mean=0,
        initial_state_covariance=1,
        observation_covariance=1,
        transition_covariance=0.01
    )
    state_means, _ = kf.filter(x.values)
    return pd.Series(state_means.flatten(), index = x.index)

def kalmanfilterRegression(x, y):
    delta = 1e-3
    trans_cov = delta / (1 - delta) * np.eye(2)
    obs_mat = np.expand_dims(np.vstack([[x], [np.ones(len(x))]]).T, axis = 1)

    kf = KalmanFilter(
        n_dim_obs=1,
        n_dim_state=2,
        initial_state_mean=[0, 0],
        initial_state_covariance=np.ones((2, 2)),
        transition_matrices=np.eye(2),
        observation_matrices=obs_mat,
        observation_covariance=2,
        transition_covariance=trans_cov
    )
    state_mean, state_covs = kf.filter(y.values)
    return state_mean[:, 0]

def halfLife(spread):
    spread_lag = spread.shift(1).fillna(method='bfill')
    spread_ret = (spread - spread_lag).fillna(method='bfill')
    spread_lag2 = sm.add_constant(spread_lag)
    model = sm.OLS(spread_ret, spread_lag2)
    res = model.fit()
    try:
        halflife = int(round(-np.log(2) / res.params[res.params.index[-1]])) if len(res.params) >= 2 else int(round(-np.log(2) / res.params[res.params.index[0]]))
    except ZeroDivisionError:
        halflife = 1
    except OverflowError:
        halflife = 1

    if halflife <= 0: return 1
    return halflife

def fitOUProcess(spread):
    delta_t = 1 / 252
    n = len(spread) - 1
    Sx = spread.iloc[:-1].sum()
    Sy = spread[1:].sum()
    Sxx = (spread.iloc[:-1] * spread.iloc[:-1]).sum()
    Sxy = (spread.iloc[:-1] * spread[1:]).sum()
    Syy = (spread[1:] * spread[1:]).sum()

    mu = (Sy * Sxx - Sx * Sxy) / (n * (Sxx - Sxy) - (Sx ** 2 - Sx * Sy))
    lamb = - np.log((Sxy - mu * (Sx + Sy) + n * mu ** 2) / (Sxx - 2 * mu * Sx + n * mu ** 2)) / delta_t
    alpha = np.exp(-lamb * delta_t)
    sig_hat = ((Syy - 2 * alpha * Sxy + alpha ** 2 * Sxx) - 2 * mu * (1 - alpha) * (Sy - alpha * Sx) + n * mu ** 2 * (1 - alpha) ** 2) / n
    sig = sig_hat ** 2 * 2 * lamb / (1 - alpha ** 2)

    return lamb

def getPairs(df_stock, lookback):
    # df_stock = readData(symbol_list) # 需分成股票跟期貨
    if df_stock.shape[0] >= lookback:
        # 用股票計算可交易之配對
        _, pairs = CoIntegration(df_stock)
        return pairs
    return None

def read_data(symbol_list):
    dataPath = os.path.join(path, 'historicalDailyKline')
    df = pd.DataFrame()
    min_daterange = None
    for f in os.listdir(dataPath):
        ticker = f.split('_')[0]
        if ticker in symbol_list:
            temp = pd.read_csv(os.path.join(dataPath, f), encoding='utf-8-sig', sep=',')
            temp['Ticker'] = ticker
            df = temp if df.empty else df.append(temp)
            if min_daterange is None: min_daterange = temp['date']
            if temp.shape[0] < len(min_daterange): min_daterange = temp['date']
    df = df[df['date'].isin(min_daterange)]
    df['date'] = pd.to_datetime(df['date'])
    df = df.loc[:,'date,Ticker,open,high,low,close,volume'.split(',')]
    df.columns = 'Date,Ticker,open,high,low,close,volume'.split(',')
    return df

def getTopNPairs(df_stock, N):
    pairs = getPairs(df_stock, lookback=100)
    if pairs != None:
        rankDF = pd.DataFrame(index=range(len(pairs)), columns='stock1,stock2,revertionRate'.split(','))
        for (stock1, stock2, pvalue) in pairs:
            x, y = df_stock[stock1], df_stock[stock2]
            # 計算避險比例
            hr = kalmanfilterRegression(kalmanfilterAverage(x.iloc[:-1]), kalmanfilterAverage(y.iloc[:-1]))
            # 計算誤差
            spread = pd.Series(y[:-1]) - hr[-1] * pd.Series(x[:-1])
            """# 計算半衰期
            halflife = halfLife(spread)
            # 計算均線與標準差
            mu = spread.rolling(halflife).mean()
            std = spread.rolling(halflife).std().fillna(0)
            # 計算進場的z_score
            try:
                z_score = ((y.iloc[-1] - hr[-1] * x.iloc[-1]) - mu.iloc[-1]) / std.iloc[-1]
            except ZeroDivisionError:
                z_score = 0"""
            # 填入DataFrame
            rankDF = rankDF.append({'stock1':stock1, 'stock2':stock2, 'revertionRate':fitOUProcess(spread)}, ignore_index=True) #, 'zscore':z_score, 'hr':hr[0]
        rankedDF = rankDF.sort_values('revertionRate', ascending=False)
        return rankedDF.iloc[:N]

def read_data_future(symbol_list):
    dataPath = os.path.join(path, 'historicalDailyKline')
    df = pd.DataFrame()
    min_daterange = None
    for f in os.listdir(dataPath):
        ticker = f.split('_')[0]
        if ticker in symbol_list:
            temp = pd.read_csv(os.path.join(dataPath, f), encoding='utf-8-sig', sep=',')
            temp['Ticker'] = ticker
            df = temp if df.empty else df.append(temp)
            if min_daterange is None:
                min_daterange = temp['date']
            elif temp.shape[0] < len(min_daterange):
                min_daterange = temp['date']
    df = df[df['date'].isin(min_daterange)]
    df['date'] = pd.to_datetime(df['date'])
    df = df.loc[:,'date,Ticker,open,high,low,close,volume'.split(',')]
    df.columns = 'Date,Ticker,open,high,low,close,volume'.split(',')
    return df

def read_symbol_list():
    with open(os.path.join(path, 'FutureStockList.txt'), 'r') as f:
        lines = f.readlines()
        return lines[4].rstrip().split(','), lines[5].rstrip().split(',')

def read_future_margin():
    with open(os.path.join(path, 'xqctrader', 'Data', 'Multipliers', 'FutureMarginMap.json'), 'r') as f:
        return json.load(f)['Margin']

def main(p0, p1, start_date = "2007/01/01"):
    p0_list = [p0]
    p1_list = [p1]
    symbol_list = p0_list + p1_list # 將股票清單與期貨清單加入到商品清單中
    point_multiplier = dict((k,v) for k, v in [(s, 1000) for s in symbol_list])
    #point_multiplier.update({'TX00':200, 'TE00':4000, 'TF00':1000, 'MTX00':50})
    type_dict = dict((k,v) for k, v in [(s, 'STOCK') for s in symbol_list])
    exchanges = dict((k,v) for k, v in [(s, "TSE") for s in symbol_list])
    pairs_map = {'p0_to_p1':{}, 'p1_to_p0':{}}
    #margin_multiplier = read_future_margin() # 期貨標的所在之交易所，用以計算commission

    for i, p0 in enumerate(p0_list):
        pairs_map['p0_to_p1'].update({p0:p1_list[i]})
        pairs_map['p1_to_p0'].update({p1_list[i]:p0})

    periods = 252 # 用來做最後報表的統計結果計算

    # Initialize EventHandler
    eventmanager = Queue()

    # Initialize DataHandler
    #data = read_data(symbol_list)
    #min(data.index)
    datahandler = DataHandler(eventmanager, symbol_list, start_date)
    
    # Initialize strategy
    # 策略的參數設定
    strat_param_dict = dict(zscore_low=0.5, zscore_high=3.0, ols_window=100)
    strategy = Strategy(datahandler, eventmanager, pairs_map, point_multiplier, type_dict, tradeStatus=TradeStatus.Backtest, dataFreq=DataFreq.Daily, **strat_param_dict)
    
    # Initialize Portfolio
    account_balance = {'Capital':10000000.0, 'Margin':10000000.0}
    portfolio = Portfolio(datahandler, eventmanager, point_multiplier, datahandler.start_date, account_balance, Real=False, pairs_map=pairs_map, type_dict=type_dict)
    
    # Initialize Profitloss
    stop_loss = 4000 / account_balance['Margin']
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
    title = f'simulate BackTest trading of {str(strategy)} with {" ".join(symbol_list)}'
    statistic = TearsheetStatistics(portfolio, datahandler, eventmanager, title=title, periods=periods)

    # Initialize RealTimeTrade
    backtest = BackTest(eventmanager, symbol_list, datahandler.start_date, datahandler, execution_handler, 
                            portfolio, strategy, profitloss, statistic,
                            periods=periods, strat_param_dict=strat_param_dict)

    # Start Trade
    start_time = time.time()
    backtest.simulate_trading()
    duration = round((time.time() - start_time) / 60, 2)
    print(f'run single pairs backtesting with {" ".join(symbol_list)} cost {duration} mins')

# realtime main program sample
if __name__ == "__main__":
    symbol_list, _ = read_symbol_list()
    symbol_list = symbol_list
    
    pool = Pool(8)
    estimation_start = datetime(2007,1,1)
    estimation_end = estimation_start + timedelta(days=365)
    df_stock = get_df_from_web_api(symbol_list, estimation_start.strftime("%Y/%m/%d"), estimation_end.strftime("%Y/%m/%d")).dropna()
    df = pd.DataFrame(index=df_stock.Date.unique(), columns = symbol_list)
    for s in symbol_list:
        temp = df_stock[df_stock.Ticker==s].set_index('Date')
        df.loc[:,s] = temp.close
    pairs = getTopNPairs(df.reset_index().dropna(axis=1, how='all').dropna(axis=0, how='any'), 5)#list(combinations(symbol_list, 2))
    print(pairs)
    start_time = time.time()
    #result = [pool.apply_async(main, args=(p0, p1)) for (p0, p1) in pairs]
    #for f in result: f.get()
    #pool.join()
    for pair in pairs.itertuples(): main(pair.stock1, pair.stock2, (estimation_end+timedelta(days=1)).strftime("%Y/%m/%d"))
    duration = time.time() - start_time
    Line.sendMessage(f'run {len(pairs)} pairs, used {round(duration/3600, 4)} hours')