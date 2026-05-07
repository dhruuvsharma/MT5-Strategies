//+------------------------------------------------------------------+
//| Market.mqh — Indicators, tick delta, spread tracking              |
//+------------------------------------------------------------------+
#ifndef MARKET_MQH
#define MARKET_MQH

#include "Config.mqh"

//+------------------------------------------------------------------+
//| Compute pip size: 1 pip = 10*Point on 3/5-digit, else 1*Point      |
//+------------------------------------------------------------------+
double CalcPipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return 10.0 * point;
   return point;
}

//+------------------------------------------------------------------+
//| Initialize indicator handles, buffers, pip size                    |
//+------------------------------------------------------------------+
bool MarketInit()
{
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_PERIOD);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print(EA_PREFIX, "ATR handle failed. Error=", GetLastError());
      return false;
   }

   g_emaHandle = iMA(_Symbol, EMA_TIMEFRAME, EMA_PERIOD, 0, MODE_EMA, PRICE_CLOSE);
   if(g_emaHandle == INVALID_HANDLE)
   {
      Print(EA_PREFIX, "EMA handle failed. Error=", GetLastError());
      return false;
   }

   g_adxHandle = iADX(_Symbol, ADX_TIMEFRAME, ADX_PERIOD);
   if(g_adxHandle == INVALID_HANDLE)
   {
      Print(EA_PREFIX, "ADX handle failed. Error=", GetLastError());
      return false;
   }

   ArrayResize(g_deltaBuffer, WindowSize);
   ArrayInitialize(g_deltaBuffer, 0);
   g_bufferIndex  = 0;
   g_bufferFilled = 0;

   ArrayResize(g_spreadHistory, SpreadHistorySize);
   ArrayInitialize(g_spreadHistory, 0);
   g_spreadHistoryIdx    = 0;
   g_spreadHistoryFilled = 0;

   g_prevBid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_pipSize     = CalcPipSize();

   Print(EA_PREFIX, "Market init OK. Pip=", g_pipSize, " Digits=", _Digits);
   return true;
}

//+------------------------------------------------------------------+
//| Release indicator handles                                         |
//+------------------------------------------------------------------+
void MarketDeinit()
{
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_emaHandle != INVALID_HANDLE) IndicatorRelease(g_emaHandle);
   if(g_adxHandle != INVALID_HANDLE) IndicatorRelease(g_adxHandle);
}

//+------------------------------------------------------------------+
//| Detect new candle by comparing bar open time                      |
//+------------------------------------------------------------------+
bool IsNewCandle()
{
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Process tick: update uptick/downtick counters via bid flip        |
//+------------------------------------------------------------------+
void ProcessTick()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > g_prevBid)      g_uptickCount++;
   else if(bid < g_prevBid) g_downtickCount++;
   g_prevBid    = bid;
   g_liveDelta  = g_uptickCount - g_downtickCount;
}

//+------------------------------------------------------------------+
//| On candle close: push delta to circular buffer, sample spread     |
//+------------------------------------------------------------------+
void FinalizeCandle()
{
   int candleDelta = g_uptickCount - g_downtickCount;

   g_deltaBuffer[g_bufferIndex] = candleDelta;
   g_bufferIndex = (g_bufferIndex + 1) % WindowSize;
   if(g_bufferFilled < WindowSize) g_bufferFilled++;

   //--- Sample spread once per bar
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_spreadHistory[g_spreadHistoryIdx] = spread;
   g_spreadHistoryIdx = (g_spreadHistoryIdx + 1) % SpreadHistorySize;
   if(g_spreadHistoryFilled < SpreadHistorySize) g_spreadHistoryFilled++;

#ifndef BACKTEST_MODE
   Print(EA_PREFIX, "Candle closed. Delta=", candleDelta,
         " Up=", g_uptickCount, " Dn=", g_downtickCount, " Spread=", spread);
#endif

   g_uptickCount   = 0;
   g_downtickCount = 0;
   g_liveDelta     = 0;
}

//+------------------------------------------------------------------+
//| Indicator readers                                                 |
//+------------------------------------------------------------------+
double GetATR()
{
   double v[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, v) <= 0) return 0.0;
   return v[0];
}

double GetHTFEma()
{
   double v[];
   if(CopyBuffer(g_emaHandle, 0, 0, 1, v) <= 0) return 0.0;
   return v[0];
}

//+------------------------------------------------------------------+
//| EMA slope direction over EMASlopeBars: +1 rising, -1 falling, 0   |
//+------------------------------------------------------------------+
int GetEMASlopeDir()
{
   int n = MathMax(EMASlopeBars, 1) + 1;
   double v[];
   if(CopyBuffer(g_emaHandle, 0, 0, n, v) < n) return 0;
   ArraySetAsSeries(v, true);
   if(v[0] > v[n - 1]) return 1;
   if(v[0] < v[n - 1]) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| ADX main line value                                               |
//+------------------------------------------------------------------+
double GetADX()
{
   double v[];
   if(CopyBuffer(g_adxHandle, 0, 0, 1, v) <= 0) return 0.0;
   return v[0];
}

int GetSpreadPoints()
{
   return (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
}

//+------------------------------------------------------------------+
//| Rolling average spread (0 if not enough samples yet)              |
//+------------------------------------------------------------------+
double GetAvgSpread()
{
   if(g_spreadHistoryFilled <= 0) return 0.0;
   long sum = 0;
   for(int i = 0; i < g_spreadHistoryFilled; i++)
      sum += g_spreadHistory[i];
   return (double)sum / (double)g_spreadHistoryFilled;
}

//+------------------------------------------------------------------+
//| Get deltas in chronological order: oldest→newest                  |
//+------------------------------------------------------------------+
int GetOrderedDeltas(int &deltas[])
{
   int count = MathMin(g_bufferFilled, WindowSize);
   ArrayResize(deltas, count);
   int start = (g_bufferFilled >= WindowSize) ? g_bufferIndex : 0;
   for(int i = 0; i < count; i++)
   {
      int idx = (start + i) % WindowSize;
      deltas[i] = g_deltaBuffer[idx];
   }
   return count;
}

#endif
