//+------------------------------------------------------------------+
//|                                                          Smc.mq5 |
//|                                         Copyright 2026, Xiaoyang |
//|                                                       wx: qhmorn |
//| 08.09.2026 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Xiaoyang"
#property link      "wx: qhmorn"
#property version   "1.00"
#include <Trade/Trade.mqh>
#define APPEND(arr, val) do {int _sz = ArraySize(arr); ArrayResize(arr, _sz + 1); arr[_sz] = (val); } while(0)

input group "Smc 交易参数"
input string SymbolNamer        = "EURUSD";
double InpLots                  = 1.10;
int    InpStopLoss              = 200;
int    InpTakeProfit            = 400;
input int    InpMagic           = 20250930;
input int    InpSlippage        = 30;
input group "=== 风控参数 ==="
input double InpMaxSpread       = 50;
input group "=== 信号参数 ==="
double previousHighLowStrength  = 0.15;
double bosStrengthAggregation   = 0.10;
double bosStrength              = 0.20;
double chochStrength            = 0.10;
double obStrength               = 0.20;
double fvgStrength              = 0.15;
double liquidityStrength        = 0.10;
double entryThreshold           = 0.55;
double strongThreshold          = 0.75;
double sltpSpread               = 0.0001;

CTrade   trade;
CPositionInfo  posInfo;
datetime g_lastBarTime      = 0;
int UseBarCount             = 200;
int swingLength             = 6;
int swingLengthAggregation  = 6;



int OnInit()
{
    trade.SetExpertMagicNumber(InpMagic);
    trade.SetDeviationInPoints(InpSlippage);
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetAsyncMode(false);
    g_lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    return INIT_SUCCEEDED;
}


void OnDeinit(const int reason)
{

    // EventKillTimer();
    // MarketBookRelease("BITCOIN");  
}


void OnTick()
{
    datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(curBarTime == 0 || curBarTime == g_lastBarTime) return;
    g_lastBarTime = curBarTime;

    MqlRates rates[];
    ArraySetAsSeries(rates, false);
    int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, UseBarCount, rates);
    if(copied < UseBarCount)
    {
        Print("CopyRates 失败, error=", GetLastError());
        return;
    }
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick))
    {
        Print("获取 Tick 失败");
        return;
    }
    double ask = tick.ask;
    double bid = tick.bid;
    int isLong = 0;
    int isShort = 0;
    double sl1 = 0;
    double tp1 = 0;
    double tp2 = 0;
    double tp3 = 0;
    generateSignals(rates, copied, _Symbol, ask, bid, isLong, isShort, sl1, tp1, tp2, tp3);
    if (isLong <= 0 && isShort <= 0)
    {
        return;
    }

    int posType = getPositionType();
    if(isLong && posType <= 0)
    {
        if(posType == -1)
        {
            if(!closeAllPositions())
            {
                Print("平空失败，放弃开多");
                return;
            }
            if(getPositionType() != 0)
            {
                Print("平空后仍有残留仓位，放弃开多");
                return;
            }
        }
        MqlTick tick;
        if(!SymbolInfoTick(_Symbol, tick))
        {
            return;
        }
        ask = tick.ask;
        bid = tick.bid;
        double spreadPoints = (ask - bid) / _Point;
        if(spreadPoints > InpMaxSpread)
        {
            PrintFormat("点差过大跳过开多: %.0f > %.0f", spreadPoints, InpMaxSpread);
            return;
        }
        double lots = normalizeLots(InpLots);
        if(!checkMargin(ORDER_TYPE_BUY, lots, ask))
        {
            Print("买入跳过: 保证金不足");
            return;
        }
        double sl = 0.0, tp = 0.0;
        if(!validateStops(ORDER_TYPE_BUY, ask, bid, sl1, tp1, tp2, tp3, sl, tp))
        {
            Print("买入跳过: 止损止盈无效");
            return;
        }
        trade.SetDeviationInPoints(InpSlippage);
        if(trade.Buy(lots, _Symbol, ask, sl, tp, "SMC Buy"))
        {
            PrintFormat("买入成功: 手数=%.2f 价格=%.5f SL=%.5f TP=%.5f", lots, ask, sl, tp);
        }
        else
        {
            PrintFormat("买入失败: retcode=%d, %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
    }
    else if(isShort && posType >= 0)
    {
        if(posType == 1)
        {
            if(!closeAllPositions())
            {
                Print("平多失败，放弃开空");
                return;
            }
            if(getPositionType() != 0)
            {
                Print("平多后仍有残留仓位，放弃开空");
                return;
            }
        }
        MqlTick tick;
        if(!SymbolInfoTick(_Symbol, tick))
        {
            return;
        }
        ask = tick.ask;
        bid = tick.bid;
        double spreadPoints = (ask - bid) / _Point;
        if(spreadPoints > InpMaxSpread)
        {
            PrintFormat("点差过大跳过开空: %.0f > %.0f", spreadPoints, InpMaxSpread);
            return;
        }
        double lots = normalizeLots(InpLots);
        if(!checkMargin(ORDER_TYPE_SELL, lots, bid))
        {
            Print("卖出跳过: 保证金不足");
            return;
        }
        double sl = 0.0, tp = 0.0;
        if(!validateStops(ORDER_TYPE_SELL, ask, bid, sl1, tp1, tp2, tp3, sl, tp))
        {
            Print("卖出跳过: 止损止盈无效");
            return;
        }
        trade.SetDeviationInPoints(InpSlippage);
        if(trade.Sell(lots, _Symbol, bid, sl, tp, "SMC Sell"))
        {
            PrintFormat("卖出成功: 手数=%.2f 价格=%.5f SL=%.5f TP=%.5f", lots, bid, sl, tp);
        }
        else
        {
            PrintFormat("卖出失败: retcode=%d, %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
    }
}
