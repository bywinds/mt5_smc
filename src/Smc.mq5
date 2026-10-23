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


void OnTimer()
{
    datetime tc = TimeCurrent();
    Print(tc);
    
}


void OnTrade()
{

    
}


void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{

    
}


double OnTester()
{

    double ret = 0.0;

   

    return(ret);
}


void OnTesterInit()
{

    
}


void OnTesterPass()
{
    
}


void OnTesterDeinit()
{

    
}


void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Print("id == : ", IntegerToString(id));
    // Alert("id: " + id);
    
}


void OnBookEvent(const string &symbol)
{

    
}




//+------------------------------------------------------------------+
//|   FVG + Swing                                                    |
//+------------------------------------------------------------------+
void generateSignals(const MqlRates& rates[], int size, string symbol, double ask, double bid, int& isLong, int& isShort, double& sl, double& tp1, double& tp2, double& tp3)
{
    int bosAggregation[];
    int chochAggregation[];
    double levelAggregation[];
    int brokenAggregation[];
    calculateTimeFrameBosChoch(rates, size, symbol, ENUM_TIMEFRAMES::PERIOD_H4, true, bosAggregation, chochAggregation, levelAggregation, brokenAggregation);

    double pvPreviousHigh[];
    double pvPreviousLow[];
    int pvBrokenHigh[];
    int pvBrokenLow[];
    calculatePreviousHighLow(size, symbol, ENUM_TIMEFRAMES::PERIOD_H4, pvPreviousHigh, pvPreviousLow, pvBrokenHigh, pvBrokenLow);

    int swingHighLows[];
    double swingLevels[];
    calculateSwingHighsLows(rates, size, swingLength, swingHighLows, swingLevels);

    int bcBos[];
    int bcChoch[];
    double bcLevel[];
    int bcBroken[];
    calculateBosChoch(rates, size, swingHighLows, swingLevels, true, bcBos, bcChoch, bcLevel, bcBroken);

    int obOb[];
    double obTop[];
    double obBottom[];
    double obObvolume[];
    int obMitigatedIndex[];
    double obPercentage[];
    calculateOb(rates, size, swingHighLows, swingLevels, false, obOb, obTop, obBottom, obObvolume, obMitigatedIndex, obPercentage);

    int fvgFvg[];
    double fvgTop[];
    double fvgBottom[];
    int fvgMitigatedIndex[];
    calculateFVG(rates, size, true, fvgFvg, fvgTop, fvgBottom, fvgMitigatedIndex);

    int liqLiquidity[];
    double liqLevel[];
    int    liqTail[];
    int    liqSwept[];
    calculateLiquidity(rates, size, swingHighLows, swingLevels, 0.01, liqLiquidity, liqLevel, liqTail, liqSwept);

    double long_score[];
    double short_score[];
    ArrayResize(long_score, size);
    ArrayResize(short_score, size);
    ArrayInitialize(long_score, 0);
    ArrayInitialize(short_score, 0);

    for(int i = 0; i < size; i++)
    {
        double pvH = pvPreviousHigh[i];
        double pvL = pvPreviousLow[i];
        int    bH  = pvBrokenHigh[i];
        int    bL  = pvBrokenLow[i];
        bool bull  = (bH == 1) && pvH > 0 && (rates[i].close > pvH);
        bool bear  = (bL == 1) && pvL > 0 && (rates[i].close < pvL);
        if(bull) long_score[i]  += previousHighLowStrength;
        if(bear) short_score[i] += previousHighLowStrength;
    }

    // 聚合成高周期，投射到低周期后，BOS/CHOCH 评分 ， 按 BrokenIndex 位置计分
    for(int i = 0; i < size; i++)
    {
        double bos  = bosAggregation[i];
        int j       = brokenAggregation[i];
        if(bos == 0  || j < 0)
        {
            continue;
        }
        if(bos == 1)
        {
            long_score[j]  += bosStrengthAggregation;
        }
        else if(bos == -1)
        {
            short_score[j] += bosStrengthAggregation;
        }
    }

    // BOS CHOCH 评分
    for(int i = 0; i < size; i++)
    {
        double bos   = bcBos[i];
        double choch = bcChoch[i];
        int j        = bcBroken[i];
        if(j < 0)
        {
            continue;
        }
        if(bos != 0)
        {
            if(bos == 1)
            {
                long_score[j]  += bosStrength;
            }
            else if(bos == -1)
            {
                short_score[j] += bosStrength;
            }
        }
        if(choch != 0)
        {
            if(choch == 1)
            {
                long_score[j]  += chochStrength;
            }
            else if(choch == -1)
            {
                short_score[j] += chochStrength;
            }
        }
    }

    // 回踩评分
    for(int i = 0; i < size; i++)
    {
        int ob = obOb[i];
        double top = obTop[i];
        double bottom = obBottom[i];
        int index = obMitigatedIndex[i];
        if(ob == 0)
        {
            continue;
        }
        int end = size - 1;
        if (index > -1)
        {
            end = index;
        }
        for(int j = i + 1; j <= end; j++)
        {
            if(ob == 1 && rates[j].low <= top && rates[j].close > top)
            {
                long_score[j] += obStrength;
                break;
            }
            if(ob == -1 && rates[j].high >= bottom && rates[j].close < bottom)
            {
                short_score[j] += obStrength;
                break;
            }
        }
    }

    // FVG 回踩评分
    for(int i = 0; i < size; i++)
    {
        int fvg = fvgFvg[i];
        double top = fvgTop[i];
        double bottom = fvgBottom[i];
        int index = fvgMitigatedIndex[i];
        if(fvg == 0)
        {
            continue;
        }
        int end = size - 1;
        if (index > -1)
        {
            end = index;
        }
        for(int j = i + 2; j <= end; j++)
        {
            if(fvg == 1 && rates[j].low <= top && rates[j].close > top)
            {
                long_score[j] += fvgStrength;
                break;
            }
            if(fvg == -1 && rates[j].high >= bottom && rates[j].close < bottom)
            {
                short_score[j] += fvgStrength;
                break;
            }
        }
    }

    // 流动性扫掠评分
    int maxGap = 50;
    for(int i = 0; i < size; i++)
    {
        int liquidity  = liqLiquidity[i];
        double level   = liqLevel[i];
        int tail       = liqTail[i];
        int j          = liqSwept[i];
        if (liquidity == 0 || j <= 0)
        {
            continue;
        }
        if (tail > -1 && (j - tail) > maxGap)
        {
            continue;
        }
        if(liquidity == -1 && rates[j].close > level)
        {
            long_score[j]  += liquidityStrength;
        }
        else if(liquidity == 1 && rates[j].close < level)
        {
            short_score[j] += liquidityStrength;
        }
    }

    int signal[];
    int strong[];
    ArrayResize(signal, size);
    ArrayResize(strong, size);
    for(int i = 0; i < size; i++)
    {
        double net = long_score[i] - short_score[i];
        if(net >=  entryThreshold)
        {
            signal[i] = 1;
        }
        else if(net <= -entryThreshold)
        {
            signal[i] = -1;
        }
        else
        {
            signal[i] = 0;
        }
        if(net >=  strongThreshold)
        {
            strong[i] = 1;
        }
        else if(net <= -strongThreshold)
        {
            strong[i] = -1;
        }
        else
        {
            strong[i] = 0;
        }
    }

    int lastIndex = size - 1;
    double sltpAtr = 0;
    double supports[];
    double longTp1Candidates[];
    double longTp2Candidates[];
    double resistances[];
    double shortTp1Candidates[];
    double shortTp2Candidates[];
    ArrayResize(supports,           0);
    ArrayResize(longTp1Candidates,  0);
    ArrayResize(longTp2Candidates,  0);
    ArrayResize(resistances,        0);
    ArrayResize(shortTp1Candidates, 0);
    ArrayResize(shortTp2Candidates, 0);
    double entry = 0;
    double atr = ATR(symbol, PERIOD_CURRENT, 14, 1);
    double buffer = MathMax(0.5 * atr, 2 * sltpSpread);
    if (signal[lastIndex] == 1)
    {
        isLong = 1;
        entry = ask;
        for(int i = lastIndex; i >= 0; i--)
        {
            if(swingHighLows[i] == -1 && swingLevels[i] > 0)
            {
                APPEND(supports, swingLevels[i]);
                break;
            }
        }
        // 最近未失效看涨 OB
        for(int i = lastIndex; i >= 0; i--)
        {
            if(obOb[i] == 1)
            {
                double mit = obMitigatedIndex[i];
                if(mit < 0 || mit >= lastIndex)
                {
                    APPEND(supports, obBottom[i]);
                    break;
                }
            }
        }
        // 最近未失效看涨 FVG
        for(int i = lastIndex; i >= 0; i--)
        {
            if(fvgFvg[i] == 1)
            {
                double mit = fvgMitigatedIndex[i];
                if(mit < 0 || mit > lastIndex)
                {
                    APPEND(supports, fvgBottom[i]);
                    break;
                }
            }
        }
        // 上方流动性 或 前高
        for(int i = lastIndex; i >= 0; i--)
        {
            if(liqLiquidity[i] == 1)
            {
                APPEND(longTp1Candidates, liqLevel[i]);
                break;
            }
        }
        if(pvPreviousHigh[lastIndex] > 0)
        {
            APPEND(longTp1Candidates, pvPreviousHigh[lastIndex]);
        }
        // 上方看跌 OB/FVG
        for(int i = lastIndex; i >= 0; i--)
        {
            if(obOb[i] == -1)
            {
                APPEND(longTp2Candidates, obTop[i]);
                break;            
            }
        }
        for(int i = lastIndex; i >= 0; i--)
        {
            if(fvgFvg[i] == -1)
            {
                APPEND(longTp2Candidates, fvgTop[i]);
                break;

            }
        }
        double _max = 0;
        double _min = 0;
        int count = ArraySize(supports);
        for(int i = 0; i < count; i++)
        {
            double item = supports[i];
            if(item < entry)
            {
                _max = MathMax(_max, item);
            }
            
        }
        double _sl = _max > 0 ? _max - buffer : entry - 1.5 * atr;

        count = ArraySize(longTp1Candidates);
        for(int i = 0; i < count; i++)
        {
            double item = longTp1Candidates[i];
            if(item > entry)
            {
                _min = MathMin(_min, item);
            }
        }
        tp1 = _min > 0 ? _min : entry + 2 * (entry - _sl);

        _min = 0;
        count = ArraySize(longTp2Candidates);
        for(int i = 0; i < count; i++)
        {
            double item = longTp2Candidates[i];
            if(item > entry)
            {
                _min = MathMin(_min, item);
            }
        }
        tp2 = _min > 0 ? _min : entry + 3 * (entry - _sl);
        tp3 = entry + 3 * (entry - _sl);
        sl =_sl;
    }
    else if (signal[lastIndex] == -1)
    {
        isShort = 1;
        entry = bid;
        for(int i = lastIndex; i >= 0; i--)
        {
            if(swingHighLows[i] == 1 && swingLevels[i] > 0)
            {
                APPEND(resistances, swingLevels[i]);
                break;
            }
        }
        for(int i = lastIndex; i >= 0; i--)
        {
            if(obOb[i] == -1)
            {
                double mit = obMitigatedIndex[i];
                if(mit < 0 || mit >= lastIndex)
                {
                    APPEND(resistances, obTop[i]);
                    break;
                }
            }
        }
        for(int i = lastIndex; i >= 0; i--)
        {
            if(fvgFvg[i] == -1)
            {
                double mit = fvgMitigatedIndex[i];
                if(mit < 0 || mit > lastIndex)
                {
                    APPEND(resistances, fvgTop[i]);
                    break;
                }
            }
        }
        for(int i = lastIndex; i >= 0; i--)
        {
            if(liqLiquidity[i] == -1)
            {
                APPEND(shortTp1Candidates, liqLevel[i]);
                break;
            }
        }
        if(pvPreviousLow[lastIndex] > 0)
        {
            APPEND(shortTp1Candidates, pvPreviousLow[lastIndex]);
        }
        for(int i = lastIndex; i >= 0; i--)
        {
            if(obOb[i] == 1)
            {
                APPEND(shortTp2Candidates, obBottom[i]);
                break;            
            }
        }
        for(int i = lastIndex; i >= 0; i--)
        {
            if(fvgFvg[i] == 1)
            {
                APPEND(shortTp2Candidates, fvgBottom[i]);
                break;

            }
        }
        double _max = 0;
        double _min = 0;
        int count = ArraySize(resistances);
        for(int i = 0; i < count; i++)
        {
            double item = resistances[i];
            if(item > entry)
            {
                _min = MathMin(_min, item);
            }
        }
        double _sl = _min > 0 ? _min + buffer : entry + 1.5 * atr;

        count = ArraySize(shortTp1Candidates);
        for(int i = 0; i < count; i++)
        {
            double item = shortTp1Candidates[i];
            if(item < entry)
            {
                _max = MathMax(_max, item);
            }
        }
        tp1 = _max > 0 ? _max : entry - 2 * (_sl - entry);

        _max = 0;
        count = ArraySize(shortTp2Candidates);
        for(int i = 0; i < count; i++)
        {
            double item = shortTp2Candidates[i];
            if(item < entry)
            {
                _max = MathMax(_max, item);
            }
        }
        tp2 = _max > 0 ? _max : entry - 3 * (_sl - entry);
        tp3 = entry - 3 * (_sl - entry);
        sl =_sl;
    }
}


double ATR(string symbol, ENUM_TIMEFRAMES period, int ma_period=14, int i = -1)
{
    int handle = iATR(symbol, period, ma_period);
    if (i == INVALID_HANDLE)
    {
        return -1;
    }
    double B[1];
    if (CopyBuffer(handle, 0, i, 1, B) != 1)
    {
        PrintFormat("Error (%s, CopyBuffer): #%d", __FUNCTION__, GetLastError());
        return -1;
    }
    return B[0];
}


void calculateFVG(const MqlRates& rates[], int size, bool join_consecutive, int &fvg[], double& top[], double& bottom[], int& mitigatedIndex[])
{
    ArrayResize(fvg, size);
    ArrayResize(top, size);
    ArrayResize(bottom, size);
    ArrayResize(mitigatedIndex, size);
    for(int i = 0; i < size; i++)
    {
        fvg[i] = 0;
        top[i] = 0;
        bottom[i] = 0;
        mitigatedIndex[i] = -1;
    }

    for(int i = 1; i < size - 1; i++)
    {
        bool bullish = (rates[i-1].high < rates[i+1].low) && (rates[i].close > rates[i].open);
        bool bearish = (rates[i-1].low  > rates[i+1].high) && (rates[i].close < rates[i].open);

        if(bullish)
        {
            fvg[i] = 1;
            top[i] = rates[i+1].low;
            bottom[i] = rates[i-1].high;
        }
        else if(bearish)
        {
            fvg[i] = -1;
            top[i] = rates[i-1].low;
            bottom[i] = rates[i+1].high;
        }
    }

    if(join_consecutive)
    {
        for(int i = 0; i < size - 1; i++)
        {
            if(fvg[i] != 0 && fvg[i] == fvg[i+1])
            {
                top[i+1] = MathMax(top[i], top[i+1]);
                bottom[i+1] = MathMin(bottom[i], bottom[i+1]);
                fvg[i] = 0;
                top[i] = 0;
                bottom[i] = 0;
            }
        }
    }

    for(int i = 0; i < size; i++)
    {
        if(fvg[i] == 0) continue;
        if(fvg[i] == 1)
        {
            for(int j = i + 2; j < size; j++)
            {
                if(rates[j].low <= top[i])
                {
                    mitigatedIndex[i] = j;
                    break;
                }
            }
        }
        else if(fvg[i] == -1)
        {
            for(int j = i + 2; j < size; j++)
            {
                if(rates[j].high >= bottom[i])
                {
                    mitigatedIndex[i] = j;
                    break;
                }
            }
        }
    }
}


void calculateSwingHighsLows(const MqlRates& rates[], int size, int swing, int& highLows[], double& levels[])
{
    ArrayResize(highLows, size);
    ArrayResize(levels, size);
    for(int i = 0; i < size; i++)
    {
        highLows[i] = 0;
        levels[i] = 0;
    }
    for (int i = swing - 1; i < size - swing; i++)
    {
        double maxHigh = rates[i - swing + 1].high;
        double minLow  = rates[i - swing + 1].low;
        for (int j = i - swing + 1; j <= i + swing; j++)
        {
            if (rates[j].high > maxHigh) maxHigh = rates[j].high;
            if (rates[j].low < minLow)   minLow  = rates[j].low;
        }
        if (rates[i].high == maxHigh)
        {
            highLows[i] = 1;
        }
        else if (rates[i].low == minLow)
        {
            highLows[i] = -1;
        }
    }

    int prev = -1;
    for (int i = 0; i < size; i++)
    {
        if (highLows[i] == 0)
        {
            continue;
        }
        if (prev != -1)
        {
            if (highLows[prev] == 1 && highLows[i] == 1)
            {
                if (rates[prev].high < rates[i].high)
                {
                    highLows[prev] = 0;
                    prev = i;
                }
                else
                {
                    highLows[i] = 0;
                }
            }
            else if (highLows[prev] == -1 && highLows[i] == -1)
            {
                if (rates[prev].low > rates[i].low)
                {
                    highLows[prev] = 0;
                    prev = i;
                }
                else
                {
                    highLows[i] = 0;
                }
            }
            else
            {
                prev = i;
            }
        }
        else
        {
            prev = i;
        }
    }

    int first = -1;
    int tail  = -1;
    for (int i = 0; i < size; i++)
    {
        if (highLows[i] != 0)
        {
            if (first == -1)
            {
                first = i;
            }
            else
            {
                tail = i;
            }
        }
    }
    if (first != -1 && tail != -1)
    {
        if (highLows[first] == 1)
        {
            highLows[0] = -1;
        }
        else if (highLows[first] == -1)
        {
            highLows[0] = 1;
        }
        if (highLows[tail] == -1)
        {
            highLows[size - 1] = 1;
        } 
        else if (highLows[tail] == 1)
        {
            highLows[size - 1] = -1;
        }
    }

    for (int i = 0; i < size; i++)
    {
        if (highLows[i] == 1)
        {
            levels[i] = rates[i].high;
        }
        else if (highLows[i] == -1)
        {
            levels[i] = rates[i].low;
        }
        else
        {
            levels[i] = 0;
        }  
    }
}


void calculateBosChoch(const MqlRates& rates[], int size, const int& highLows[], const double& levels[], bool closeBreak, int& bos[], int& choch[], double& level[], int& broken[])
{  
    ArrayResize(bos, size);
    ArrayResize(choch, size);
    ArrayResize(level, size);
    ArrayResize(broken, size);
    for(int i = 0; i < size; i++)
    {
        bos[i] = 0;
        choch[i] = 0;
        level[i] = 0;
        broken[i] = -1;
    }

    int    lastPositions[];
    double levelOrder[];
    int    highLowOrder[];
    ArrayResize(lastPositions, 0);
    ArrayResize(levelOrder, 0);
    ArrayResize(highLowOrder, 0);

    for(int i = 0; i < size; i++)
    {
        int hl = highLows[i];
        if(hl == 0)
        {
            continue;
        }
        int sz = ArraySize(levelOrder);
        ArrayResize(levelOrder,   sz + 1);
        ArrayResize(highLowOrder, sz + 1);
        highLowOrder[sz] = hl;
        levelOrder[sz]   = levels[i];

        int m = sz + 1;
        if(m >= 4)
        {
            int L1 = m - 4;
            int L2 = m - 3;
            int L3 = m - 2;
            int L4 = m - 1;
            int nlp    = ArraySize(lastPositions);
            int target = lastPositions[nlp - 2];

            bool isBullBOS =
                (highLowOrder[L1] == -1 && highLowOrder[L2] ==  1 &&
                 highLowOrder[L3] == -1 && highLowOrder[L4] ==  1 &&
                 levelOrder[L1] < levelOrder[L3] &&
                 levelOrder[L3] < levelOrder[L2] &&
                 levelOrder[L2] < levelOrder[L4]);

            bos[target]   = (isBullBOS ? 1 : 0);
            level[target] = (bos[target] != 0 ? levelOrder[L2] : 0);

            bool isBearBOS =
                (highLowOrder[L1] ==  1 && highLowOrder[L2] == -1 &&
                 highLowOrder[L3] ==  1 && highLowOrder[L4] == -1 &&
                 levelOrder[L1] > levelOrder[L3] &&
                 levelOrder[L3] > levelOrder[L2] &&
                 levelOrder[L2] > levelOrder[L4]);

            if(isBearBOS) bos[target] = -1;
            level[target] = (bos[target] != 0 ? levelOrder[L2] : 0);

            bool isBullCHoCH =
                (highLowOrder[L1] == -1 && highLowOrder[L2] ==  1 &&
                 highLowOrder[L3] == -1 && highLowOrder[L4] ==  1 &&
                 levelOrder[L4] > levelOrder[L2] &&
                 levelOrder[L2] > levelOrder[L1] &&
                 levelOrder[L1] > levelOrder[L3]);

            choch[target] = (isBullCHoCH ? 1 : 0);
            if(choch[target] != 0) level[target] = levelOrder[L2];

            bool isBearCHoCH =
                (highLowOrder[L1] ==  1 && highLowOrder[L2] == -1 &&
                 highLowOrder[L3] ==  1 && highLowOrder[L4] == -1 &&
                 levelOrder[L4] < levelOrder[L2] &&
                 levelOrder[L2] < levelOrder[L1] &&
                 levelOrder[L1] < levelOrder[L3]);

            if(isBearCHoCH) choch[target] = -1;
            if(choch[target] != 0) level[target] = levelOrder[L2];
        }
        int nlp2 = ArraySize(lastPositions);
        ArrayResize(lastPositions, nlp2 + 1);
        lastPositions[nlp2] = i;
    }
    for(int i = 0; i < size; i++)
    {
        if(bos[i] == 0 && choch[i] == 0)
        {
            continue;
        }
        bool isBull = (bos[i] == 1 || choch[i] == 1);
        bool isBear = (bos[i] == -1 || choch[i] == -1);

        for(int j = i + 2; j < size; j++)
        {
            bool broke = false;

            if(isBull)
            {
                double px = (closeBreak ? rates[j].close : rates[j].high);
                if(px > level[i])
                {
                    broke = true;
                }
            }
            else if(isBear)
            {
                double px = (closeBreak ? rates[j].close : rates[j].low);
                if(px < level[i])
                {
                    broke = true;
                }
            }
            if(broke)
            {
                broken[i] = j;
                for(int k = 0; k < i; k++)
                {
                    if((bos[k] != 0 || choch[k] != 0) && broken[k] >= j)
                    {
                        bos[k]   = 0;
                        choch[k] = 0;
                        level[k] = 0;
                        broken[k]   = -1;
                    }
                }
                break;
            }
        }
    }
    for(int i = 0; i < size; i++)
    {
        if((bos[i] != 0 || choch[i] != 0) && broken[i] == -1)
        {
            bos[i]   = 0;
            choch[i] = 0;
            level[i] = 0;
        }
    }
}


void calculateOb(const MqlRates& rates[], int size, const int& highLows[], const double& levels[], bool closeMitigation, 
    int& ob[], double& top[], double& bottom[], double& obvolume[], int& mitigatedIndex[], double& percentage[])
{
    ArrayResize(ob, size);
    ArrayResize(top, size);
    ArrayResize(bottom, size);
    ArrayResize(obvolume, size);
    ArrayResize(mitigatedIndex, size);
    ArrayResize(percentage, size);
    for(int i = 0; i < size; i++)
    {
        ob[i]             = 0;
        top[i]            = 0;
        bottom[i]         = 0;
        obvolume[i]       = 0;
        mitigatedIndex[i] = -1;
        percentage[i]     = 0;
    }
    // 预计算摆动高点/低点索引
    int swingHighIdx[];
    int swingLowIdx[];
    ArrayResize(swingHighIdx, 0);
    ArrayResize(swingLowIdx,  0);
    for(int i = 0; i < size; i++)
    {
        if(highLows[i] == 1)
        {
            int sz = ArraySize(swingHighIdx);
            ArrayResize(swingHighIdx, sz + 1);
            swingHighIdx[sz] = i;
        }
        else if(highLows[i] == -1)
        {
            int sz = ArraySize(swingLowIdx);
            ArrayResize(swingLowIdx, sz + 1);
            swingLowIdx[sz] = i;
        }
    }
    // 工作数组
    bool   crossed[];
    bool   breaker[];
    double lowVolume[];
    double highVolume[];
    ArrayResize(crossed,    size);
    ArrayResize(breaker,    size);
    ArrayResize(lowVolume,  size);
    ArrayResize(highVolume, size); 
    ArrayInitialize(crossed,    false);
    ArrayInitialize(breaker,    false);
    ArrayInitialize(lowVolume,  0);
    ArrayInitialize(highVolume, 0);

    // 看涨订单块
    int activeBull[];
    ArrayResize(activeBull, 0);
    for(int close_index = 0; close_index < size; close_index++)
    {
        // 更新已有的看涨 OB
        for(int i = 0; i < ArraySize(activeBull); i++)
        {
            int idx = activeBull[i];
            if(breaker[idx])
            {
                // 已被缓解，但价格又向上突破 OB 顶部 => 重置并移除
                if(rates[close_index].high > top[idx])
                {
                    ob[idx]             = 0;
                    top[idx]            = 0;
                    bottom[idx]         = 0;
                    obvolume[idx]       = 0;
                    lowVolume[idx]      = 0;
                    highVolume[idx]     = 0;
                    mitigatedIndex[idx] = -1;
                    percentage[idx]     = 0;
                    ArrayRemove(activeBull, i, 1);
                    i--;
                }
            }
            else
            {
                bool mitigate;
                if(!closeMitigation)
                {
                    mitigate = (rates[close_index].low < bottom[idx]);
                }
                else
                {
                    mitigate = (MathMin(rates[close_index].open, rates[close_index].close) < bottom[idx]);
                }
                if(mitigate)
                {
                    breaker[idx]         = true;
                    mitigatedIndex[idx]  = close_index - 1;
                }
            }
        }

        // 找到 close_index 之前最近的摆动高点
        int last_top_index = -1;
        int lo = 0;
        int hi = ArraySize(swingHighIdx) - 1;
        if(hi >= 0 && close_index > swingHighIdx[0])
        {
            if(hi == 0)
            {
                last_top_index = swingHighIdx[0];
            }
            else if (hi == 1)
            {
                if (close_index > swingHighIdx[1])
                {
                    last_top_index = swingHighIdx[1];
                }
                else
                {
                    last_top_index = swingHighIdx[0];
                }
            }
            else
            {
                while(lo < hi - 1)
                {
                    int mider = (lo + hi) / 2;
                    if(swingHighIdx[mider] < close_index)
                    {
                        lo = mider;
                    }
                    else
                    {
                        hi = mider;
                    }
                }
                last_top_index = swingHighIdx[lo];
            }
        }
        // 若收盘价突破该摆动高点且未 cross 过，创建看涨
        if(last_top_index >= 0)
        {
            if(rates[close_index].close > rates[last_top_index].high && !crossed[last_top_index])
            {
                crossed[last_top_index] = true;
                int    default_index    = close_index - 1;
                double obBtm            = rates[default_index].low;
                double obTop            = rates[default_index].high;
                int    obIndex          = default_index;

                // 在 (last_top_index, close_index) 之间寻找最低的低点
                if(close_index - last_top_index > 1)
                {
                    int start = last_top_index + 1;
                    int tail   = close_index;
                    if(tail > start)
                    {
                        double minVal  = rates[start].low;
                        int    candIdx = start;
                        for(int i = start + 1; i < tail; i++)
                        {
                            // 相等时取最后一个
                            if(rates[i].low <= minVal)
                            {
                                minVal  = rates[i].low;
                                candIdx = i;
                            }
                        }
                        obBtm   = rates[candIdx].low;
                        obTop   = rates[candIdx].high;
                        obIndex = candIdx;
                    }
                }
                ob[obIndex]     = 1;
                top[obIndex]    = obTop;
                bottom[obIndex] = obBtm;

                double vol_cur   = (double)rates[close_index].real_volume;
                double vol_prev1 = (close_index >= 1) ? (double)rates[close_index - 1].real_volume : 0.0;
                double vol_prev2 = (close_index >= 2) ? (double)rates[close_index - 2].real_volume : 0.0;
                obvolume[obIndex] = vol_cur + vol_prev1 + vol_prev2;

                lowVolume[obIndex]   = vol_prev2;
                highVolume[obIndex]  = vol_cur + vol_prev1;
                double max_vol = MathMax(highVolume[obIndex], lowVolume[obIndex]);
                percentage[obIndex] = (max_vol != 0.0) ? (MathMin(highVolume[obIndex], lowVolume[obIndex]) / max_vol * 100.0) : 100.0;

                int sz = ArraySize(activeBull);
                ArrayResize(activeBull, sz + 1);
                activeBull[sz] = obIndex;
            }
        }
    }

    // 看跌订单块
    int activeBear[];
    ArrayResize(activeBear, 0);
    for(int close_index = 0; close_index < size; close_index++)
    {
        // 更新已有的看跌
        for(int i = 0; i < ArraySize(activeBear); i++)
        {
            int idx = activeBear[i];
            if(breaker[idx])
            {
                // 已被失效，但价格又向下突破 OB 底部 => 重置并移除
                if(rates[close_index].low < bottom[idx])
                {
                    ob[idx]             = 0;
                    top[idx]            = 0;
                    bottom[idx]         = 0;
                    obvolume[idx]       = 0;
                    lowVolume[idx]      = 0;
                    highVolume[idx]     = 0;
                    mitigatedIndex[idx] = -1;
                    percentage[idx]     = 0;
                    ArrayRemove(activeBear, i, 1);
                    i--;
                }
            }
            else
            {
                bool mitigate;
                if(!closeMitigation)
                {
                    mitigate = (rates[close_index].high > top[idx]);
                }  
                else
                {
                    mitigate = (MathMax(rates[close_index].open, rates[close_index].close) > top[idx]);
                }
                if(mitigate)
                {
                    breaker[idx]         = true;
                    mitigatedIndex[idx]  = close_index;
                }
            }
        }
        int last_btm_index = -1;
        int lo = 0;
        int hi = ArraySize(swingLowIdx) - 1;
        if(hi >= 0 && close_index > swingLowIdx[0])
        {
            if(hi == 0)
            {
                last_btm_index = swingLowIdx[0];
            }
            else if (hi == 1)
            {
                if (close_index > swingLowIdx[1])
                {
                    last_btm_index = swingLowIdx[1];
                }
                else
                {
                    last_btm_index = swingLowIdx[0];
                }
            }
            else
            {
                while(lo < hi - 1)
                {
                    int mider = (lo + hi) / 2;
                    if(swingLowIdx[mider] < close_index)
                    {
                        lo = mider;
                    }
                    else
                    {
                        hi = mider;
                    }
                }
                last_btm_index = swingLowIdx[lo];
            }
        }
        // 若收盘价跌破该摆动低点且未 cross 过，创建看跌 OB
        if(last_btm_index >= 0)
        {
            if(rates[close_index].close < rates[last_btm_index].low && !crossed[last_btm_index])
            {
                crossed[last_btm_index] = true;
                int    default_index    = close_index - 1;
                double obTop            = rates[default_index].high;
                double obBtm            = rates[default_index].low;
                int    obIndex          = default_index;
                if(close_index - last_btm_index > 1)
                {
                    int start = last_btm_index + 1;
                    int tail   = close_index;
                    if(tail > start)
                    {
                        double maxVal  = rates[start].high;
                        int    candIdx = start;
                        for(int i = start + 1; i < tail; i++)
                        {
                            if(rates[i].high >= maxVal)
                            {
                                maxVal  = rates[i].high;
                                candIdx = i;
                            }
                        }
                        obTop   = rates[candIdx].high;
                        obBtm   = rates[candIdx].low;
                        obIndex = candIdx;
                    }
                }
                ob[obIndex]     = -1;
                top[obIndex]    = obTop;
                bottom[obIndex] = obBtm;

                double vol_cur   = (double)rates[close_index].real_volume;
                double vol_prev1 = (close_index >= 1) ? (double)rates[close_index - 1].real_volume : 0.0;
                double vol_prev2 = (close_index >= 2) ? (double)rates[close_index - 2].real_volume : 0.0;
                obvolume[obIndex] = vol_cur + vol_prev1 + vol_prev2;

                lowVolume[obIndex]   = vol_cur + vol_prev1;
                highVolume[obIndex]  = vol_prev2;
                double max_vol = MathMax(highVolume[obIndex], lowVolume[obIndex]);
                percentage[obIndex] = (max_vol != 0.0) ? (MathMin(highVolume[obIndex], lowVolume[obIndex]) / max_vol * 100.0) : 100.0;

                int sz = ArraySize(activeBear);
                ArrayResize(activeBear, sz + 1);
                activeBear[sz] = obIndex;
            }
        }
    }
}


void calculateLiquidity(const MqlRates& rates[], int size, const int& highLows[], const double& levels[], double rangePercent, int& liquidity[], double& level[], int& tail[], int& swept[])
{
    ArrayResize(liquidity, size);
    ArrayResize(level,     size);
    ArrayResize(tail,      size);
    ArrayResize(swept,     size);
    for(int i = 0; i < size; i++)
    {
        liquidity[i] = 0;
        level[i]     = 0;
        tail[i]      = -1;
        swept[i]     = -1;
    }

    double maxHigh = rates[0].high;
    double maxLow  = rates[0].low;
    for(int i = 1; i < size; i++)
    {
        if(rates[i].high > maxHigh)
        {
            maxHigh = rates[i].high;
        }
        if(rates[i].low < maxLow)
        {
            maxLow = rates[i].low;
        }
    }
    double pip_range = (maxHigh - maxLow) * rangePercent;

    int    HL[];
    double LV[];
    ArrayResize(HL, size);
    ArrayResize(LV, size);
    ArrayCopy(HL, highLows, 0, 0, size);
    ArrayCopy(LV, levels,   0, 0, size);

    // 看涨（上方）流动性: HighLow == 1
    for(int i = 0; i < size; i++)
    {
        if(HL[i] != 1)
        {
            continue;
        }
        double high_level = LV[i];
        double rng_low    = high_level - pip_range;
        double rng_high   = high_level + pip_range;
        double group_sum  = high_level;
        int    group_cnt  = 1;
        int    group_end  = i;
        // 找扫掠 K 线: i 之后第一根 high >= rng_high
        int sw = 0;
        for(int j = i + 1; j < size; j++)
        {
            if(rates[j].high >= rng_high) {
                sw = j;
                break;
            }
        }
        // 收集同一范围内的其它看涨摆动点
        for(int j = i + 1; j < size; j++)
        {
            if(HL[j] != 1)
            {
                continue;
            }
            if(sw > 0 && j >= sw)
            {
                break; 
            }
            if(LV[j] >= rng_low && LV[j] <= rng_high)
            {
                group_sum += LV[j];
                group_cnt++;
                group_end = j;
                HL[j]     = 0;
            }
        }
        if(group_cnt > 1)
        {
            liquidity[i]  =  1;
            level[i]      =  group_sum / group_cnt;
            tail[i]       =  group_end;
            swept[i]      =  sw;
        }
    }
    // 看跌（下方）流动性: HighLow == -1
    for(int i = 0; i < size; i++)
    {
        if(HL[i] != -1)
        {
            continue;
        }
        double low_level = LV[i];
        double rng_low   = low_level - pip_range;
        double rng_high  = low_level + pip_range;
        double group_sum = low_level;
        int    group_cnt = 1;
        int    group_end = i;
        int sw = 0;
        for(int j = i + 1; j < size; j++)
        {
            if(rates[j].low <= rng_low) {
                sw = j;
                break;
            }
        }
        for(int j = i + 1; j < size; j++)
        {
            if(HL[j] != -1)
            {
                continue;
            }
            if(sw > 0 && j >= sw)
            {
                break;
            }
            if(LV[j] >= rng_low && LV[j] <= rng_high)
            {
                group_sum += LV[j];
                group_cnt++;
                group_end = j;
                HL[j]     = 0;
            }
        }
        if(group_cnt > 1)
        {
            liquidity[i] = -1;
            level[i]     =  group_sum / group_cnt;
            tail[i]      =  group_end;
            swept[i]     =  sw;
        }
    }
}


void calculatePreviousHighLow(int size, string symbol, ENUM_TIMEFRAMES timeFrame, double& previousHigh[], double& previousLow[], int& brokenHigh[], int& brokenLow[])
{
    ArrayResize(previousHigh,      size);
    ArrayResize(previousLow,       size);
    ArrayResize(brokenHigh,        size);
    ArrayResize(brokenLow,         size);
    for(int i = 0; i < size; i++)
    {
        previousHigh[i]     = 0;
        previousLow[i]      = 0;
        brokenHigh[i]       = 0;
        brokenLow[i]        = 0;
    }
    int highBars = Bars(symbol, timeFrame);
    for(int shift = 0; shift < size; shift++)
    {
        datetime curTime = iTime(symbol, PERIOD_CURRENT, shift);
        if(curTime == 0)
        {
            continue;
        }
        int highShift = iBarShift(symbol, timeFrame, curTime, false);
        if(highShift < 0)
        {
            continue;
        }
        if(highShift + 1 >= highBars)
        {
            continue;
        }
        double prevHigh = iHigh(symbol, timeFrame, highShift + 1);
        double prevLow  = iLow (symbol, timeFrame, highShift + 1);
        if(prevHigh == 0.0 || prevLow == 0.0)
        {
            continue;
        }

        datetime groupStartTime = iTime(symbol, timeFrame, highShift);
        int groupStartLowShift = iBarShift(symbol, PERIOD_CURRENT, groupStartTime, false);
        if(groupStartLowShift < shift)
        {
            groupStartLowShift = shift;
        }

        double cumHigh = -DBL_MAX;
        double cumLow  = DBL_MAX;
        for(int s = groupStartLowShift; s >= shift; --s)
        {
            double h = iHigh(symbol, PERIOD_CURRENT, s);
            double l = iLow (symbol, PERIOD_CURRENT, s);
            if(h == 0.0 && l == 0.0)
            {
                continue;
            } 
            if(h > cumHigh) cumHigh = h;
            if(l < cumLow ) cumLow  = l;
        }
        int reverse_index = size - 1 - shift;
        previousHigh[reverse_index]     = prevHigh;
        previousLow[reverse_index]      = prevLow;
        brokenHigh[reverse_index]       = (cumHigh > prevHigh) ? 1 : 0;
        brokenLow[reverse_index]        = (cumLow  < prevLow ) ? 1 : 0;
    }
}


void calculateTimeFrameBosChoch(const MqlRates& rates[], int size, string symbol, ENUM_TIMEFRAMES timeFrame, bool closeBreak, int& bos[], int& choch[], double& level[], int& broken[])
{
    ArrayResize(bos,    size);
    ArrayResize(choch,  size);
    ArrayResize(level,  size);
    ArrayResize(broken, size);
    for(int i = 0; i < size; i++)
    {
        bos[i] = 0;
        choch[i] = 0;
        level[i] = 0;
        broken[i] = -1;
    }
    MqlRates rates_aggregation[];
    int size_aggregation = resample(rates, size, symbol, timeFrame, rates_aggregation);
    if (size_aggregation > 0)
    {
        int swingHighLows[];
        double swingLevels[];
        calculateSwingHighsLows(rates_aggregation, size_aggregation, swingLengthAggregation, swingHighLows, swingLevels);
        int bos_aggregation[];
        int choch_aggregation[];
        double level_aggregation[];
        int broken_aggregation[];
        calculateBosChoch(rates_aggregation, size_aggregation, swingHighLows, swingLevels, closeBreak, bos_aggregation, choch_aggregation, level_aggregation, broken_aggregation);
        for(int shift = 0; shift < size; shift++)
        {
            datetime curTime = rates[shift].time;
            if(curTime == 0)
            {
                continue;
            }
            int highShift = iBarShift(symbol, timeFrame, curTime, false);
            if(highShift < 0)
            {
                continue;
            }      
            int reverse_index = size_aggregation - 1 - highShift;
            if(reverse_index < 0 || reverse_index >= size_aggregation)
            {
                continue;
            }
            bos[shift]    = bos_aggregation[reverse_index];
            choch[shift]  = choch_aggregation[reverse_index];
            level[shift]  = level_aggregation[reverse_index];
            int j         = broken_aggregation[reverse_index];
            if (j < 0)
            {
                broken[shift] = - 1;
            }
            else if (j >= size_aggregation -1)
            {
                broken[shift] = size - 1;
            }
            else
            {
                datetime nextTime = rates_aggregation[j + 1].time;
                int nextShift = iBarShift(symbol, PERIOD_CURRENT, nextTime, false);
                int targetShift = size - 1 - (nextShift + 1);
                broken[shift] = targetShift;
            }
        }
    }
}


int resample(const MqlRates& rates[], int size, string symbol, ENUM_TIMEFRAMES timeFrame, MqlRates& rates_aggregation[])
{
    int highIndexOldest = iBarShift(symbol, timeFrame, rates[0].time, false);
    int highIndexNewest = iBarShift(symbol, timeFrame, rates[size-1].time, false);
    if(highIndexOldest < 0 || highIndexNewest < 0)
    {
        return 0;
    }
    int highBarsCount = highIndexOldest - highIndexNewest + 1;
    if(highBarsCount <= 0)
    {
        return 0;
    }
    ArraySetAsSeries(rates_aggregation, false);
    int copiedHigh = CopyRates(symbol, timeFrame, highIndexNewest, highBarsCount, rates_aggregation);
    if(copiedHigh == highBarsCount)
    {
        return copiedHigh;
    }
    return 0;
}


int getPositionType()
{
    int total = PositionsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0)
        {
            continue;
        }
        if(!PositionSelectByTicket(ticket))
        {
            continue;
        }
        if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
        {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(type == POSITION_TYPE_BUY)
            {
                return 1;
            }
            if(type == POSITION_TYPE_SELL)
            {
                return -1;
            }
        }
    }
    return 0;
}


bool closeAllPositions()
{
    bool allClosed = true;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0)
        {
            continue;
        }
        if(!PositionSelectByTicket(ticket))
        {
            continue;
        }
        if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
        {
            if(!trade.PositionClose(ticket))
            {
                PrintFormat("平仓失败 ticket=%I64u retcode=%d %s", ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
                allClosed = false;
            }
            else
            {
                PrintFormat("平仓成功 ticket=%I64u", ticket);
            }
        }
    }
    return allClosed;
}


double normalizeLots(double lots)
{
    double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(stepLot <= 0)
    {
        stepLot = 0.01;
    }
    lots = MathRound(lots / stepLot) * stepLot;
    lots = MathMax(minLot, MathMin(maxLot, lots));
    int lotDigits = (int)MathMax(0, -MathLog10(stepLot));
    return NormalizeDouble(lots, lotDigits);
}


bool checkMargin(ENUM_ORDER_TYPE type, double lots, double price)
{
    double margin = 0.0;
    if(!OrderCalcMargin(type, _Symbol, lots, price, margin))
    {
        Print("OrderCalcMargin 失败");
        return true;
    }
    if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
    {
        PrintFormat("保证金不足: 需要=%.2f 可用=%.2f", margin, AccountInfoDouble(ACCOUNT_MARGIN_FREE));
        return false;
    }
    return true;
}


bool validateStops(ENUM_ORDER_TYPE type, double ask, double bid, double sl1, double tp1, double tp2, double tp3, double &sl, double &tp)
{
    sl = 0;
    tp = 0;
    double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

    if(type == ORDER_TYPE_BUY)
    {
        if(InpStopLoss > 0)
        {
            sl = ask - InpStopLoss * _Point;
            if(sl < sl1 && sl1 < ask)
            {
                sl = sl1;
            }
            if(bid - sl < stopsLevel)
            {
                sl = bid - stopsLevel;
            }
        }
        if(InpTakeProfit > 0)
        {
            tp = ask + InpTakeProfit * _Point;
            double tp0 = (tp1 + tp2) / 2;
            if(tp > tp0 && tp0 > ask)
            {
                tp = tp0;
            }
            if(tp - ask < stopsLevel)
            {
                tp = ask + stopsLevel;
            }
        }
    }
    else if(type == ORDER_TYPE_SELL)
    {
        if(InpStopLoss > 0)
        {
            sl = bid + InpStopLoss * _Point;
            if(sl > sl1 && sl1 > bid)
            {
                sl = sl1;
            }
            if(sl - ask < stopsLevel)
            {
                sl = ask + stopsLevel;
            }
        }
        if(InpTakeProfit > 0)
        {
            tp = bid - InpTakeProfit * _Point;
            double tp0 = (tp1 + tp2) / 2;
            if(tp < tp0 && tp0 < bid)
            {
                tp = tp0;
            }
            if(bid - tp < stopsLevel) 
            {
                tp = bid - stopsLevel;
            }
        }
    }
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    return true;
}


int readCSVFile(string fileName, MqlRates &data[])
{
    int handle = FileOpen(fileName, FILE_READ | FILE_CSV | FILE_ANSI, ',', CP_UTF8);
    if(handle == INVALID_HANDLE)
    {
        Print("无法打开文件: ", fileName, " 错误码: ", GetLastError());
        return 0;
    }

    int rowCount = 0;
    if(!FileIsEnding(handle))
    {
        for(int i = 0; i < 4; i++)
            {
                FileReadString(handle);
            }
    }
    while(!FileIsEnding(handle))
    {
        string sOpen  = FileReadString(handle);
        if(StringLen(sOpen) == 0)
        {
            break;
        }
        string sHigh  = FileReadString(handle);
        string sLow   = FileReadString(handle);
        string sClose = FileReadString(handle);
        ArrayResize(data, rowCount + 1);
        data[rowCount].open  = StringToDouble(sOpen);
        data[rowCount].high  = StringToDouble(sHigh);
        data[rowCount].low   = StringToDouble(sLow);
        data[rowCount].close = StringToDouble(sClose);
        rowCount++;
    }

    FileClose(handle);
    Print("成功读取 ", rowCount, " 行数据");
    return rowCount;
}

