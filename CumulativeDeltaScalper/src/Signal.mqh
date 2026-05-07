//+------------------------------------------------------------------+
//| Signal.mqh — Cumulative delta crossover + confirmation stack      |
//+------------------------------------------------------------------+
#ifndef SIGNAL_MQH
#define SIGNAL_MQH

#include "Market.mqh"

//+------------------------------------------------------------------+
//| Sum the sliding-window deltas                                     |
//+------------------------------------------------------------------+
int CalculateCumDelta()
{
   int sum = 0;
   int count = MathMin(g_bufferFilled, WindowSize);
   for(int i = 0; i < count; i++)
      sum += g_deltaBuffer[i];
   return sum;
}

//+------------------------------------------------------------------+
//| Trigger: cumDelta crosses ±DeltaThreshold                          |
//| 1=BUY (cross up), -1=SELL (cross down), 0=none                    |
//+------------------------------------------------------------------+
int DeltaCrossover()
{
   if(g_bufferFilled < WindowSize) return 0;

   int cumDelta = CalculateCumDelta();
   int prev     = g_prevCumDelta;
   g_prevCumDelta = cumDelta;

   if(prev <= DeltaThreshold && cumDelta > DeltaThreshold)
      return 1;
   if(prev >= -DeltaThreshold && cumDelta < -DeltaThreshold)
      return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Confirmation 1: last 3 candle deltas all share signal sign        |
//+------------------------------------------------------------------+
bool CheckMomentumAlignment(int signal)
{
   int deltas[];
   int count = GetOrderedDeltas(deltas);
   if(count < 3) return false;
   for(int i = count - 3; i < count; i++)
   {
      if(signal > 0 && deltas[i] <= 0) return false;
      if(signal < 0 && deltas[i] >= 0) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Confirmation 2: bid on the correct side of HTF EMA(50, M15)       |
//+------------------------------------------------------------------+
bool CheckHTFEMA(int signal)
{
   if(!UseHTFFilter) return true;   // Filter off → treated as passing
   double ema = GetHTFEma();
   if(ema == 0.0) return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(signal > 0) return bid > ema;
   if(signal < 0) return bid < ema;
   return false;
}

//+------------------------------------------------------------------+
//| Confirmation 3: HTF EMA slope sign matches signal direction       |
//+------------------------------------------------------------------+
bool CheckEMASlope(int signal)
{
   int slope = GetEMASlopeDir();
   if(signal > 0) return slope > 0;
   if(signal < 0) return slope < 0;
   return false;
}

//+------------------------------------------------------------------+
//| Confirmation 4: ADX above threshold (regime is trending)          |
//+------------------------------------------------------------------+
bool CheckADXTrending()
{
   return GetADX() >= ADXThreshold;
}

//+------------------------------------------------------------------+
//| Confirmation 5: current spread within multiplier of rolling avg   |
//+------------------------------------------------------------------+
bool CheckSpreadDynamic()
{
   int spread = GetSpreadPoints();
   if(spread > MaxSpreadPoints) return false;
   double avg = GetAvgSpread();
   if(avg <= 0) return true;   // bootstrap window — allow
   return (double)spread <= avg * SpreadAvgMultiplier;
}

//+------------------------------------------------------------------+
//| Sniper signal: crossover + N-of-5 supporting confirmations        |
//| Returns direction (1/-1) only if MinConfirmations met, else 0     |
//+------------------------------------------------------------------+
int CheckSniperSignal()
{
   int signal = DeltaCrossover();
   if(signal == 0) return 0;

   int conf = 0;
   if(CheckMomentumAlignment(signal)) conf++;
   if(CheckHTFEMA(signal))            conf++;
   if(CheckEMASlope(signal))          conf++;
   if(CheckADXTrending())             conf++;
   if(CheckSpreadDynamic())           conf++;

   if(conf < MinConfirmations)
   {
#ifndef BACKTEST_MODE
      Print(EA_PREFIX, "Signal rejected. Direction=", signal,
            " Confirmations=", conf, "/5 (need ", MinConfirmations, ")");
#endif
      return 0;
   }

#ifndef BACKTEST_MODE
   Print(EA_PREFIX, "SNIPER SIGNAL ", (signal > 0 ? "BUY" : "SELL"),
         " confirmations=", conf, "/5");
#endif
   return signal;
}

#endif
