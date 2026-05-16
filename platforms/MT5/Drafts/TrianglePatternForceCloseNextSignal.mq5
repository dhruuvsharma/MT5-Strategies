//+------------------------------------------------------------------+
//|               TrianglePatternWithSuperTrendFilter.mq5           |
//|                                                     Dhruv Sharma |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      ""
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Generic/ArrayList.mqh>


input double   InpLotSize     = 0.1;       // Lot size
input int      InpStopLoss    = 200;        // Stop Loss (points)
input int      InpTakeProfit  = 200;       // Take Profit (points)

// Input parameters
input bool    UseDynamicLot = true;         // Enable dynamic lot sizing
input double  AccountSizeForBaseLot = 100.0;// Account balance per base lot
input double  BaseLot = 0.01;              // Base lot size
input double  TP_Param = 0.5;              // Take Profit in price units
input int     MagicNumber = 12345;         // EA Magic Number
input int     Slippage = 3;                // Allowed slippage
input string  TradingStartTime = "12:00";  // Start time (HH:MM)
input string  TradingEndTime = "16:00";    // End time (HH:MM)

// SuperTrend parameters
input int     ATR_Period = 10;             // ATR period for SuperTrend
input double  ATR_Multiplier = 3.0;        // Multiplier for SuperTrend

// RSI parameters
input int     RSI_Period = 14;             // RSI period
input double  OverboughtLevel = 70;        // RSI Overbought level
input double  OversoldLevel = 30;          // RSI Oversold level

// Global variables
datetime lastBarTime;
CTrade trade;
MqlTick last_tick;
int atrHandle, rsiHandle;
double superTrendUpper, superTrendLower;
bool superTrendBullish = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   lastBarTime = 0;
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   
   // Initialize indicators
   atrHandle = iATR(_Symbol, _Period, ATR_Period);
   rsiHandle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   
   if(atrHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
   {
      Print("Failed to initialize indicators");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "HH_Triangle_");
   ObjectsDeleteAll(0, "LL_Triangle_");
   IndicatorRelease(atrHandle);
   IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!SymbolInfoTick(_Symbol, last_tick)) return;
   if(!IsWithinTradingHours()) return;
   
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   if(Bars(_Symbol, _Period) < 4) return;

   // Update indicators
   UpdateSuperTrend();
   double rsiValue = GetRSIValue();

   // Get price data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 4, rates) < 4) return;

   // Calculate triangle conditions
   double hhMiddleLine = (rates[3].high + rates[1].high) / 2;
   double llMiddleLine = (rates[3].low + rates[1].low) / 2;
   
   color hhColor = clrRed;
   if(rates[2].high > hhMiddleLine) hhColor = clrLime;
   
   color llColor = clrRed;
   if(rates[2].low > llMiddleLine) llColor = clrLime;

   DrawTriangles(hhColor, llColor, rates);

   // Trading logic
   if(hhColor == llColor)
   {
      CloseAllPositions();
      double lotSize = CalculateLotSize();

      // Get all conditions
      bool triangleBuySignal = (hhColor == clrLime);
      bool triangleSellSignal = (hhColor == clrRed);
      bool superTrendBuy = superTrendBullish;
      bool superTrendSell = !superTrendBullish;
      bool rsiBuyCondition = (rsiValue >= OverboughtLevel);
      bool rsiSellCondition = (rsiValue <= OversoldLevel);

      // Execute trades only when all conditions align
      if(triangleBuySignal)
      {
         // Both triangles green - place sell stop
         double entryPrice = rates[2].high;
         double sl = entryPrice + InpStopLoss * _Point;
         double tp = entryPrice - InpTakeProfit * _Point;
         
         trade.SellStop(
            InpLotSize,
            entryPrice,
            _Symbol,
            sl,
            tp,
            ORDER_TIME_GTC,
            0,
            "SellStop by TriangleEA"
         );
      }
      else if(triangleSellSignal)
      {
         double entryPrice = rates[2].low;
         double sl = entryPrice - InpStopLoss * _Point;
         double tp = entryPrice + InpTakeProfit * _Point;
         
         trade.BuyStop(
            InpLotSize,
            entryPrice,
            _Symbol,
            sl,
            tp,
            ORDER_TIME_GTC,
            0,
            "BuyStop by TriangleEA"
         ); 
      }
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check trading hours                                              |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt_now;
   TimeCurrent(dt_now);
   
   string startParts[];
   string endParts[];
   StringSplit(TradingStartTime, StringGetCharacter(":", 0), startParts);
   StringSplit(TradingEndTime, StringGetCharacter(":", 0), endParts);
   
   if(ArraySize(startParts) < 2 || ArraySize(endParts) < 2) return false;
   
   int startHour = (int)StringToInteger(startParts[0]);
   int startMinute = (int)StringToInteger(startParts[1]);
   int endHour = (int)StringToInteger(endParts[0]);
   int endMinute = (int)StringToInteger(endParts[1]);
   
   int currentTime = dt_now.hour * 3600 + dt_now.min * 60 + dt_now.sec;
   int startTime = startHour * 3600 + startMinute * 60;
   int endTime = endHour * 3600 + endMinute * 60;
   
   return (currentTime >= startTime && currentTime <= endTime);
}

//+------------------------------------------------------------------+
//| Calculate position size based on balance                         |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(!UseDynamicLot) return BaseLot;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot = (balance / AccountSizeForBaseLot) * BaseLot;
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   lot = NormalizeDouble(lot, 2);
   
   return lot;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw triangle patterns on chart                                  |
//+------------------------------------------------------------------+
void DrawTriangles(color hhCol, color llCol, MqlRates &rates[])
{
   // Delete previous objects
   ObjectsDeleteAll(0, "HH_Triangle_");
   ObjectsDeleteAll(0, "LL_Triangle_");

   // Create HH Triangle
   string hhName = "HH_Triangle_" + TimeToString(rates[1].time);
   ObjectCreate(0, hhName, OBJ_TRIANGLE, 0, 
                rates[3].time, rates[3].high,
                rates[2].time, rates[2].high,
                rates[1].time, rates[1].high);
   ObjectSetInteger(0, hhName, OBJPROP_COLOR, hhCol);
   ObjectSetInteger(0, hhName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, hhName, OBJPROP_BACK, true);

   // Create LL Triangle
   string llName = "LL_Triangle_" + TimeToString(rates[1].time);
   ObjectCreate(0, llName, OBJ_TRIANGLE, 0, 
                rates[3].time, rates[3].low,
                rates[2].time, rates[2].low,
                rates[1].time, rates[1].low);
   ObjectSetInteger(0, llName, OBJPROP_COLOR, llCol);
   ObjectSetInteger(0, llName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, llName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Update SuperTrend values                                         |
//+------------------------------------------------------------------+
void UpdateSuperTrend()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2) return;

   double atrVal[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrVal) <= 0) return;
   
   double median = (rates[1].high + rates[1].low) / 2;
   double basicUpper = median + ATR_Multiplier * atrVal[0];
   double basicLower = median - ATR_Multiplier * atrVal[0];
   
   if(rates[1].close > superTrendUpper)
      superTrendUpper = basicUpper;
   else
      superTrendUpper = MathMin(basicUpper, superTrendUpper);
   
   if(rates[1].close < superTrendLower)
      superTrendLower = basicLower;
   else
      superTrendLower = MathMax(basicLower, superTrendLower);
   
   superTrendBullish = rates[1].close > superTrendUpper;
}

//+------------------------------------------------------------------+
//| Get current RSI value                                            |
//+------------------------------------------------------------------+
double GetRSIValue()
{
   double rsi[];
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0) return -1;
   return rsi[0];
}
