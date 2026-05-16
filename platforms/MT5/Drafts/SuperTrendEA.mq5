//+------------------------------------------------------------------+
//|                                                 SuperTrendEA.mq5 |
//|                                                     Dhruv Sharma |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      ""
#property version   "1.00"


#include <Trade\Trade.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
// SuperTrend Parameters
input int      ATRPeriod = 10;
input double   ATRMultiplier = 3.0;
input bool     ChangeATR = true;

// EMA Filter Parameters
input bool     UseEMAFilter = true;      // Enable EMA Filter
input int      EMA_Period = 200;         // EMA Period
input ENUM_APPLIED_PRICE EMA_Price = PRICE_CLOSE; // EMA Price Source

// ADX Trend Strength Filter
input bool     UseADXFilter = false;     // Enable ADX Filter
input int      ADX_Period = 14;          // ADX Period
input double   ADX_Threshold = 25.0;     // ADX Minimum Threshold

// Risk Management
input int      StopLoss = 100;
input int      TakeProfit = 300;
input double   LotSize = 0.1;
input ulong    MagicNumber = 12345;
input string   TradeComment = "SuperTrend Pro EA";

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
double prevUp, prevDn;
int prevTrend = 1;
int atrHandle, emaHandle, adxHandle;
CiMA ema;
CiADX adx;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Initialize ATR
   if(ChangeATR)
   {
      atrHandle = iATR(_Symbol, _Period, ATRPeriod);
      if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);
   }

   // Initialize EMA
   if(UseEMAFilter)
   {
      emaHandle = iMA(_Symbol, _Period, EMA_Period, 0, MODE_EMA, EMA_Price);
      if(emaHandle == INVALID_HANDLE) return(INIT_FAILED);
      ema.Attach(emaHandle);
   }

   // Initialize ADX
   if(UseADXFilter)
   {
      adxHandle = iADX(_Symbol, _Period, ADX_Period);
      if(adxHandle == INVALID_HANDLE) return(INIT_FAILED);
      adx.Attach(adxHandle);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(atrHandle);
   IndicatorRelease(emaHandle);
   IndicatorRelease(adxHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar()) return;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 3) return;

   // Get current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get indicator values
   double atrValue[];
   if(ChangeATR && CopyBuffer(atrHandle, 0, 0, 3, atrValue) < 3) return;

   // Calculate SuperTrend
   double src = (rates[1].high + rates[1].low) / 2;
   double up = src - (ATRMultiplier * atrValue[1]);
   double dn = src + (ATRMultiplier * atrValue[1]);

   if(Close[2] > prevUp) up = MathMax(up, prevUp);
   if(Close[2] < prevDn) dn = MathMin(dn, prevDn);

   int currentTrend = prevTrend;
   if(prevTrend == -1 && rates[1].close > prevDn) currentTrend = 1;
   else if(prevTrend == 1 && rates[1].close < prevUp) currentTrend = -1;

   // Additional Filters
   bool emaFilterOK = true;
   bool adxFilterOK = true;

   if(UseEMAFilter)
   {
      double emaValue[];
      if(CopyBuffer(emaHandle, 0, 0, 3, emaValue) < 3) return;
      emaFilterOK = (currentTrend == 1 && rates[1].close > emaValue[1]) ||
                    (currentTrend == -1 && rates[1].close < emaValue[1]);
   }

   if(UseADXFilter)
   {
      double adxValue[];
      if(CopyBuffer(adxHandle, 0, 0, 3, adxValue) < 3) return;
      adxFilterOK = adxValue[1] > ADX_Threshold;
   }

   if(currentTrend != prevTrend && emaFilterOK && adxFilterOK)
   {
      CloseAllPositions();
      if(currentTrend == 1)
         Buy();
      else if(currentTrend == -1)
         Sell();
   }

   prevUp = up;
   prevDn = dn;
   prevTrend = currentTrend;
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastTime = 0;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if(lastTime != currentTime)
     {
      lastTime = currentTime;
      return true;
     }
   return false;
}

double CalculateTR(MqlRates &r[], int index)
{
   double tr1 = r[index].high - r[index].low;
   double tr2 = MathAbs(r[index].high - r[index+1].close);
   double tr3 = MathAbs(r[index].low - r[index+1].close);
   return MathMax(tr1, MathMax(tr2, tr3));
}

void CloseAllPositions()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            trade.PositionClose(ticket);
        }
     }
}

//+------------------------------------------------------------------+
//| Buy function with enhanced validation                            |
//+------------------------------------------------------------------+
void Buy()
{
   if(PositionsTotal() > 0) return; // Prevent multiple entries
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = ask - StopLoss * _Point;
   double tp = ask + TakeProfit * _Point;
   
   // Additional price validation
   if(ask == 0 || sl <= 0 || tp <= 0) return;
   
   trade.Buy(LotSize, _Symbol, ask, sl, tp, TradeComment);
}

//+------------------------------------------------------------------+
//| Sell function with enhanced validation                           |
//+------------------------------------------------------------------+
void Sell()
{
   if(PositionsTotal() > 0) return; // Prevent multiple entries
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = bid + StopLoss * _Point;
   double tp = bid - TakeProfit * _Point;
   
   // Additional price validation
   if(bid == 0 || sl <= 0 || tp <= 0) return;
   
   trade.Sell(LotSize, _Symbol, bid, sl, tp, TradeComment);
}
//+------------------------------------------------------------------+
