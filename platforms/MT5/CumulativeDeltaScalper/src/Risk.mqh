//+------------------------------------------------------------------+
//| Risk.mqh — Sessions, lot sizing, stop distances, guard checks    |
//+------------------------------------------------------------------+
#ifndef RISK_MQH
#define RISK_MQH

#include "Signal.mqh"

//+------------------------------------------------------------------+
//| Convert hours+minutes to total minutes since GMT midnight         |
//+------------------------------------------------------------------+
int _MinutesSinceMidnightGMT()
{
   MqlDateTime gmt;
   TimeToStruct(TimeGMT(), gmt);
   return gmt.hour * 60 + gmt.min;
}

bool _InRange(int total, int sH, int sM, int eH, int eM)
{
   int s = sH * 60 + sM;
   int e = eH * 60 + eM;
   return total >= s && total < e;
}

//+------------------------------------------------------------------+
//| Determine which active session contains the current GMT time     |
//+------------------------------------------------------------------+
ENUM_SESSION_ID GetCurrentSessionID()
{
   int t = _MinutesSinceMidnightGMT();

   if(OverlapOnly)
   {
      if(_InRange(t, OverlapStartHour, OverlapStartMin, OverlapEndHour, OverlapEndMin))
         return SESSION_OVERLAP;
      return SESSION_NONE;
   }

   if(UseAsiaSession   && _InRange(t, AsiaStartHour,   AsiaStartMin,   AsiaEndHour,   AsiaEndMin))
      return SESSION_ASIA;
   if(UseLondonSession && _InRange(t, LondonStartHour, LondonStartMin, LondonEndHour, LondonEndMin))
      return SESSION_LONDON;
   if(UseNewYorkSession&& _InRange(t, NYStartHour,     NYStartMin,     NYEndHour,     NYEndMin))
      return SESSION_NY;
   return SESSION_NONE;
}

string SessionName(ENUM_SESSION_ID s)
{
   switch(s)
   {
      case SESSION_ASIA:    return "ASIA";
      case SESSION_LONDON:  return "LONDON";
      case SESSION_NY:      return "NY";
      case SESSION_OVERLAP: return "OVERLAP";
   }
   return "NONE";
}

//+------------------------------------------------------------------+
//| Reset session-scoped counters when active session changes         |
//+------------------------------------------------------------------+
void UpdateSessionState()
{
   ENUM_SESSION_ID s = GetCurrentSessionID();
   if(s != g_currentSession)
   {
      g_sessionTradeCount = 0;
      g_sessionWins       = 0;
      g_sessionLosses     = 0;
      g_currentSession    = s;
#ifndef BACKTEST_MODE
      Print(EA_PREFIX, "Session → ", SessionName(s));
#endif
   }
}

bool IsInSession()
{
   if(!UseSessionFilter) return true;
   return GetCurrentSessionID() != SESSION_NONE;
}

//+------------------------------------------------------------------+
//| Enforce broker minimum stop distance with safety buffer           |
//+------------------------------------------------------------------+
double EnsureMinStopDistance(double dist)
{
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDist  = stopsLevel * point;
   if(minDist > 0 && dist < minDist * STOPS_LEVEL_BUFFER_MULT)
      return minDist * STOPS_LEVEL_BUFFER_MULT;
   return dist;
}

//+------------------------------------------------------------------+
//| Stop distances anchored to ATR with broker-stops-level guard      |
//+------------------------------------------------------------------+
double CalcSLDistance()
{
   double atr = GetATR();
   double d = atr * SL_Multiplier;
   d = EnsureMinStopDistance(d);
   return NormalizeDouble(d, _Digits);
}

double CalcTPDistance()
{
   double atr = GetATR();
   double d = atr * TP_Multiplier;
   d = EnsureMinStopDistance(d);
   return NormalizeDouble(d, _Digits);
}

//+------------------------------------------------------------------+
//| Risk-based lot sizing: lots that lose RiskPercent at SL distance  |
//+------------------------------------------------------------------+
double CalcLotSize()
{
   if(!UseRiskBasedSizing)
      return NormalizeDouble(FixedLotSize, 2);

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercentPerTrade / 100.0;
   double slDist     = CalcSLDistance();
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(slDist <= 0 || tickValue <= 0 || tickSize <= 0)
      return NormalizeDouble(FixedLotSize, 2);

   double lossPerLot = (slDist / tickSize) * tickValue;
   if(lossPerLot <= 0)
      return NormalizeDouble(FixedLotSize, 2);

   double lots = riskAmount / lossPerLot;

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double cap = MathMin(maxLot, MaxLotSize);
   if(lots < minLot) lots = minLot;
   if(lots > cap)    lots = cap;
   if(stepLot > 0)   lots = MathFloor(lots / stepLot) * stepLot;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Guard sub-checks (each returns false + reason on block)           |
//+------------------------------------------------------------------+
bool _GuardSession(string &reason)
{
   if(!UseSessionFilter) return true;
   if(GetCurrentSessionID() == SESSION_NONE)
   {
      reason = "SESSION CLOSED";
      return false;
   }
   return true;
}

bool _GuardSpreadHardCap(string &reason)
{
   int spread = GetSpreadPoints();
   if(spread > MaxSpreadPoints)
   {
      reason = "SPREAD HIGH (" + IntegerToString(spread) + ">" + IntegerToString(MaxSpreadPoints) + ")";
      return false;
   }
   return true;
}

bool _GuardCounts(string &reason)
{
   if(g_dailyTradeCount >= MaxDailyTrades)
   {
      reason = "DAILY LIMIT (" + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(MaxDailyTrades) + ")";
      return false;
   }
   if(g_sessionTradeCount >= MaxTradesPerSession)
   {
      reason = "SESSION LIMIT (" + IntegerToString(g_sessionTradeCount) + "/" + IntegerToString(MaxTradesPerSession) + ")";
      return false;
   }
   if(StopAfterFirstWin && g_sessionWins >= 1)
   {
      reason = "SESSION HALT (post-win)";
      return false;
   }
   if(StopAfterFirstLoss && g_sessionLosses >= 1)
   {
      reason = "SESSION HALT (post-loss)";
      return false;
   }
   return true;
}

bool _GuardLossLimit(string &reason)
{
   if(g_dayStartBalance <= 0) return true;
   double maxLoss = g_dayStartBalance * MaxDailyLossPercent / 100.0;
   if(g_dailyPnL < -maxLoss)
   {
      reason = "DAILY LOSS LIMIT";
      return false;
   }
   return true;
}

bool _GuardCooldowns(string &reason)
{
   datetime now = TimeCurrent();
   if(g_lastTradeTime > 0 && now < g_lastTradeTime + MinSecondsBetweenTrades)
   {
      int rem = (int)(g_lastTradeTime + MinSecondsBetweenTrades - now);
      reason = "INTER-TRADE COOLDOWN (" + IntegerToString(rem) + "s)";
      return false;
   }
   if(g_lastLossTime > 0 && now < g_lastLossTime + LossCooldownMinutes * 60)
   {
      int rem = (int)(g_lastLossTime + LossCooldownMinutes * 60 - now) / 60;
      reason = "LOSS COOLDOWN (" + IntegerToString(rem) + "m)";
      return false;
   }
   return true;
}

bool _GuardVolatility(string &reason)
{
   double atr = GetATR();
   if(atr < MinATR)
   {
      reason = "ATR LOW (" + DoubleToString(atr, 5) + ")";
      return false;
   }
   if(atr > MaxATR)
   {
      reason = "ATR HIGH (" + DoubleToString(atr, 5) + ")";
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Master guard: returns true only if all sub-guards pass            |
//+------------------------------------------------------------------+
bool CheckGuards(string &reason)
{
   if(!_GuardSession(reason))        return false;
   if(!_GuardSpreadHardCap(reason))  return false;
   if(!_GuardCounts(reason))         return false;
   if(!_GuardLossLimit(reason))      return false;
   if(!_GuardCooldowns(reason))      return false;
   if(!_GuardVolatility(reason))     return false;
   reason = "ACTIVE " + SessionName(g_currentSession);
   return true;
}

#endif
