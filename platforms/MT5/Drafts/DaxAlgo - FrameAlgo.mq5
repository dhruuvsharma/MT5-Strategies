//+------------------------------------------------------------------+
//|                                          DaxAlgo - FrameAlgo.mq5 |
//|                                                     Dhruv Sharma |
//|                              www.linkedin.com/in/dhruvsharmainfo |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      "www.linkedin.com/in/dhruvsharmainfo"
#property version   "1.01"

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

// Input parameters
input double LotSize                  = 0.1;       // Lot size
input bool   EnableTrailing           = true;      // Enable Trailing Stop
input int    TrailingDistance         = 500;       // Trailing Step (points)
input bool   DirectExecute            = false;     // Direct Execution Mode
input bool   SmartPendingOrder        = true;      // Smart Pending Order Mode
input bool   UnitStoploss             = false;     // Use Unit Stoploss
input bool   RectangleHLStoploss      = true;      // Use Rectangle H/L Stoploss
input int    InitialStoplossUnit      = 1000;      // Initial Stoploss (points)
input bool   HoldTradeNextDay         = false;     // Hold Trades Overnight
input bool   UseTradingHours          = true;      // Enable trading hours filter
input string TradingStartTime         = "13:00";   // Start time (HH:MM)
input string TradingEndTime           = "16:00";   // End time (HH:MM)
input color  BuyRectangle             = clrGreen;  // Buy rectangle color
input color  SellRectangle            = clrRed;    // Sell rectangle color

// Session display inputs
input group  "=== Session Display Settings ==="
input bool   ShowSessions             = true;      // Show Session Rectangles
input bool   ShowAsianSession         = true;      // Show Asian Session
input string AsianSessionStart        = "00:00";   // Asian Session Start (HH:MM)
input string AsianSessionEnd          = "08:00";   // Asian Session End (HH:MM)
input color  AsianSessionColor        = clrYellow; // Asian Session Color
input bool   ShowLondonSession        = true;      // Show London Session
input string LondonSessionStart       = "08:00";   // London Session Start (HH:MM)
input string LondonSessionEnd         = "16:00";   // London Session End (HH:MM)
input color  LondonSessionColor       = clrBlue;   // London Session Color
input bool   ShowNewYorkSession       = true;      // Show New York Session
input string NewYorkSessionStart     = "13:00";   // New York Session Start (HH:MM)
input string NewYorkSessionEnd       = "22:00";   // New York Session End (HH:MM)
input color  NewYorkSessionColor     = clrRed;    // New York Session Color
input bool   ShowPacificSession       = true;      // Show Pacific Session
input string PacificSessionStart     = "22:00";   // Pacific Session Start (HH:MM)
input string PacificSessionEnd       = "06:00";   // Pacific Session End (HH:MM)
input color  PacificSessionColor     = clrGreen;  // Pacific Session Color
input int    SessionOpacity           = 20;        // Session Rectangle Opacity (0-100)

// Session structure
struct SessionInfo {
   string name;
   string startTime;
   string endTime;
   color sessionColor;
   bool enabled;
};

SessionInfo sessions[4];
datetime lastSessionUpdate = 0;

CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;
datetime lastBarTime, lastDayCheck;
string currentRectName = "";  // Track current rectangle

// Delta calculation variables
struct BarDelta {
   datetime barStart;
   long positiveTicks;
   long negativeTicks;
};
BarDelta barDeltas[3];    // Stores delta for last 3 completed bars
int deltaCount = 0;       // Number of completed bars stored
long currentBarPositiveTicks = 0;
long currentBarNegativeTicks = 0;
double lastTickPrice = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(12345);
   // Validate input combinations
   if(DirectExecute == SmartPendingOrder) {
      Print("Error: Only one entry mode can be active!");
      return(INIT_FAILED);
   }
   if(UnitStoploss == RectangleHLStoploss) {
      Print("Error: Only one stoploss mode can be active!");
      return(INIT_FAILED);
   }
   // Initialize delta tracking
   lastTickPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
   for(int i = 0; i < 3; i++)
   {
      barDeltas[i].barStart = 0;
      barDeltas[i].positiveTicks = 0;
      barDeltas[i].negativeTicks = 0;
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

   // Update tick delta for current bar
   UpdateTickDelta();
   
   // Always draw the monitoring rectangle
   DrawMonitoringRectangle();
   
      // Update session rectangles periodically
   if(ShowSessions && (TimeCurrent() - lastSessionUpdate > 3600)) { // Update every hour
      UpdateSessionRectangles();
      lastSessionUpdate = TimeCurrent();
   }
   
   // Daily trade cleanup
   if(!HoldTradeNextDay && IsNewDay()) {
      CloseAllPositions();
      DeleteAllOrders();
   }

   // Main trading logic
   if(IsNewBar()) {
   
      // Save previous bar's delta
      SaveCompletedBarDelta();
      
      MqlRates candles[];
      if(CopyRates(_Symbol, _Period, 1, 3, candles) == 3) {
         ProcessCandles(candles);
      }
   }
   
   if(UseTradingHours && !IsWithinTradingHours()) return;
   if(EnableTrailing) ManageTrailingStop();
}

//+------------------------------------------------------------------+
//| Update tick delta for current bar                                |
//+------------------------------------------------------------------+
void UpdateTickDelta()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
   
   if(lastTickPrice == 0) {
      lastTickPrice = currentPrice;
      return;
   }
   
   if(currentPrice > lastTickPrice) {
      currentBarPositiveTicks++;
   }
   else if(currentPrice < lastTickPrice) {
      currentBarNegativeTicks++;
   }
   
   lastTickPrice = currentPrice;
}

//+------------------------------------------------------------------+
//| Save completed bar's delta data                                  |
//+------------------------------------------------------------------+
void SaveCompletedBarDelta()
{
   datetime completedBarTime = iTime(_Symbol, _Period, 1); // Time of completed bar
   
   if(deltaCount < 3) {
      // Add to available slot
      barDeltas[deltaCount].barStart = completedBarTime;
      barDeltas[deltaCount].positiveTicks = currentBarPositiveTicks;
      barDeltas[deltaCount].negativeTicks = currentBarNegativeTicks;
      deltaCount++;
   }
   else {
      // Shift array: oldest to newest (index 0 is oldest)
      for(int i = 0; i < 2; i++) {
         barDeltas[i] = barDeltas[i+1];
      }
      // Add new at index 2
      barDeltas[2].barStart = completedBarTime;
      barDeltas[2].positiveTicks = currentBarPositiveTicks;
      barDeltas[2].negativeTicks = currentBarNegativeTicks;
   }
   
   // Reset counters for new bar
   currentBarPositiveTicks = 0;
   currentBarNegativeTicks = 0;
}

//+------------------------------------------------------------------+
//| Update session rectangles                                        |
//+------------------------------------------------------------------+
void UpdateSessionRectangles()
{
   if(!ShowSessions) return;
   
   // Get current date for session calculation
   MqlDateTime dtCurrent;
   TimeCurrent(dtCurrent);
   
   // Calculate sessions for last 7 days to ensure visibility
   for(int dayOffset = 0; dayOffset < 7; dayOffset++)
   {
      datetime baseDate = TimeCurrent() - dayOffset * 86400; // 86400 seconds in a day
      MqlDateTime dtBase;
      TimeToStruct(baseDate, dtBase);
      
      for(int i = 0; i < 4; i++)
      {
         if(!sessions[i].enabled) continue;
         
         DrawSessionRectangle(sessions[i], dtBase, dayOffset);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw individual session rectangle                                |
//+------------------------------------------------------------------+
void DrawSessionRectangle(const SessionInfo &session, const MqlDateTime &baseDate, int dayOffset)
{
   // Parse session times
   string startParts[], endParts[];
   if(StringSplit(session.startTime, ':', startParts) != 2) return;
   if(StringSplit(session.endTime, ':', endParts) != 2) return;
   
   int startHour = (int)StringToInteger(startParts[0]);
   int startMin = (int)StringToInteger(startParts[1]);
   int endHour = (int)StringToInteger(endParts[0]);
   int endMin = (int)StringToInteger(endParts[1]);
   
   // Create session start and end times
   MqlDateTime dtStart = baseDate;
   dtStart.hour = startHour;
   dtStart.min = startMin;
   dtStart.sec = 0;
   
   MqlDateTime dtEnd = baseDate;
   dtEnd.hour = endHour;
   dtEnd.min = endMin;
   dtEnd.sec = 0;
   
   datetime sessionStart = StructToTime(dtStart);
   datetime sessionEnd = StructToTime(dtEnd);
   
   // Handle sessions that cross midnight (like Pacific session)
   if(sessionEnd <= sessionStart) {
      dtEnd.day += 1;
      sessionEnd = StructToTime(dtEnd);
   }
   
   // Get price data for the session period
   MqlRates rates[];
   int barsInPeriod = CopyRates(_Symbol, _Period, sessionStart, sessionEnd, rates);
   
   if(barsInPeriod <= 0) return;
   
   // Find session high and low
   double sessionHigh = rates[0].high;
   double sessionLow = rates[0].low;
   
   for(int j = 1; j < barsInPeriod; j++)
   {
      if(rates[j].high > sessionHigh) sessionHigh = rates[j].high;
      if(rates[j].low < sessionLow) sessionLow = rates[j].low;
   }
   
   // Create rectangle name with date to make it unique
   string rectName = "Session_" + session.name + "_" +
                    IntegerToString(dtStart.year) + "_" +
                    IntegerToString(dtStart.mon) + "_" +
                    IntegerToString(dtStart.day);

   if(ObjectFind(0, rectName) >= 0) ObjectDelete(0, rectName);

   if(ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, sessionStart, sessionLow, sessionEnd, sessionHigh))
   {
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, session.sessionColor);
      ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
      ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
      ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, true);

      long colorValue = (long)session.sessionColor;
      long alpha      = (long)MathMax(0, MathMin(255, (SessionOpacity * 255) / 100));
      colorValue      = (alpha << 24) | (colorValue & 0xFFFFFF);
      ObjectSetInteger(0, rectName, OBJPROP_BGCOLOR, colorValue);
   }

   string labelName = "SessionLabel_" + session.name + "_" +
                     IntegerToString(dtStart.year) + "_" +
                     IntegerToString(dtStart.mon) + "_" +
                     IntegerToString(dtStart.day);

   if(ObjectFind(0, labelName) >= 0) ObjectDelete(0, labelName);

   double   labelPrice = sessionHigh + (sessionHigh - sessionLow) * 0.05;
   datetime labelTime  = sessionStart + (sessionEnd - sessionStart) / 2;

   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, labelPrice))
   {
      ObjectSetString (0, labelName, OBJPROP_TEXT,        session.name + " Session");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR,       session.sessionColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE,    8);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR,      ANCHOR_CENTER);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN,      true);
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(reason == REASON_REMOVE)
   {
      ObjectsDeleteAll(0, "Session_");
      ObjectsDeleteAll(0, "SessionLabel_");
      ObjectsDeleteAll(0, "HH_Triangle_");
      ObjectsDeleteAll(0, "LL_Triangle_");
      ObjectsDeleteAll(0, "Pattern_");
      ObjectsDeleteAll(0, "PatternInfo_");
      ObjectsDeleteAll(0, "HighTri_");
      ObjectsDeleteAll(0, "LowTri_");
      ObjectDelete(0, "MonitoringRect");
      ObjectDelete(0, "VolumeLabel");
   }
}

//+------------------------------------------------------------------+
//| Draw monitoring rectangle                                        |
//+------------------------------------------------------------------+
void DrawMonitoringRectangle()
{
   MqlRates candles[];
   if(CopyRates(_Symbol, _Period, 1, 3, candles) < 3) return;
   
   MqlRates c1 = candles[0], c2 = candles[1], c3 = candles[2];
   double high = MathMax(MathMax(c1.high, c2.high), c3.high);
   double low = MathMin(MathMin(c1.low, c2.low), c3.low);
   
   // Calculate total volume
   long totalVolume = c1.tick_volume + c2.tick_volume + c3.tick_volume;
   
   // Calculate pattern area
   double patternArea = (high - low) / _Point;
   
   // Calculate pattern delta if available
   long patternDelta = 0;
   bool hasDelta = (deltaCount >= 3);
   if(hasDelta) {
      long totalPositive = barDeltas[0].positiveTicks + barDeltas[1].positiveTicks + barDeltas[2].positiveTicks;
      long totalNegative = barDeltas[0].negativeTicks + barDeltas[1].negativeTicks + barDeltas[2].negativeTicks;
      patternDelta = totalPositive - totalNegative;
   }
   
   // Create or update rectangle
   string rectName = "MonitoringRect";
   datetime startTime = c1.time;
   datetime endTime = c3.time + PeriodSeconds(_Period);
   
   if(ObjectFind(0, rectName) < 0) {
      ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, startTime, low, endTime, high);
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, false);
      ObjectSetInteger(0, rectName, OBJPROP_FILL, false);
      ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, true);
   } else {
      ObjectMove(0, rectName, 0, startTime, low);
      ObjectMove(0, rectName, 1, endTime, high);
   }
   
   double labelPrice = high + (high - low) * 0.1; // 10% above rectangle
   
   // Create label text
   string labelText = "Vol: " + DoubleToString(totalVolume, 0) + 
                     " | Area: " + DoubleToString(patternArea, 0) + " pts";
                     
   if(hasDelta) {
      labelText += " | Delta: " + IntegerToString(patternDelta);
   }
   
   // Create or update volume label
   string volName = "VolumeLabel";
   
   if(ObjectFind(0, volName) < 0) {
      ObjectCreate(0, volName, OBJ_TEXT, 0, startTime, labelPrice);
      ObjectSetString(0, volName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, volName, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, volName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, volName, OBJPROP_BACK, true);
   } else {
      ObjectMove(0, volName, 0, startTime, labelPrice);
      ObjectSetString(0, volName, OBJPROP_TEXT, labelText);
   }
   
   currentRectName = rectName;
   
   // Draw triangles
   double hhMiddleLine = (c3.high + c1.high) /2;
   double llMiddleLine = (c3.low+ c1.low) /2;
   color hhColor = clrRed;
   if(c2.high > hhMiddleLine) hhColor = clrLime;
   
   color llColor = clrRed;
   if(c2.low > llMiddleLine) llColor = clrLime;

   DrawTriangles(hhColor, llColor, c1,c2,c3);
}

//+------------------------------------------------------------------+
//| Draw triangle patterns on chart                                  |
//+------------------------------------------------------------------+
void DrawTriangles(color hhCol, color llCol, const MqlRates &c1, const MqlRates &c2, const MqlRates &c3)
{
   // Delete previous objects
   ObjectsDeleteAll(0, "HH_Triangle_");
   ObjectsDeleteAll(0, "LL_Triangle_");

   // Create HH Triangle
   string hhName = "HH_Triangle_" + TimeToString(c1.time);
   ObjectCreate(0, hhName, OBJ_TRIANGLE, 0, 
                c3.time, c3.high,
                c2.time, c2.high,
                c1.time, c1.high);
   ObjectSetInteger(0, hhName, OBJPROP_COLOR, hhCol);
   ObjectSetInteger(0, hhName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, hhName, OBJPROP_BACK, true);

   // Create LL Triangle
   string llName = "LL_Triangle_" + TimeToString(c1.time);
   ObjectCreate(0, llName, OBJ_TRIANGLE, 0, 
                c3.time, c3.low,
                c2.time, c2.low,
                c1.time, c1.low);
   ObjectSetInteger(0, llName, OBJPROP_COLOR, llCol);
   ObjectSetInteger(0, llName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, llName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Process candle patterns                                          |
//+------------------------------------------------------------------+
void ProcessCandles(MqlRates &candles[])
{
      MqlRates c1 = candles[0], c2 = candles[1], c3 = candles[2];
   double patternHigh = MathMax(MathMax(c1.high, c2.high), c3.high);
   double patternLow = MathMin(MathMin(c1.low, c2.low), c3.low);
   
   // Calculate pattern area in points
   double patternArea = (patternHigh - patternLow) / _Point;
   
   // Calculate total volume for trade comment
   long totalVolume = c1.tick_volume + c2.tick_volume + c3.tick_volume;
   
      // Calculate pattern delta if available
   long patternDelta = 0;
   bool hasDelta = (deltaCount >= 3);
   if(hasDelta) {
      long totalPositive = barDeltas[0].positiveTicks + barDeltas[1].positiveTicks + barDeltas[2].positiveTicks;
      long totalNegative = barDeltas[0].negativeTicks + barDeltas[1].negativeTicks + barDeltas[2].negativeTicks;
      patternDelta = totalPositive - totalNegative;
   }
   
      // Build comment string
   string comment = "V: " + DoubleToString(totalVolume, 0) + 
                   "|A: " + DoubleToString(patternArea, 0) ;
                   
   if(hasDelta) {
      comment += "|D: " + IntegerToString(patternDelta);
   }
   
   bool sellSignal = CheckSellCondition(c1, c2, c3);
   bool buySignal = CheckBuyCondition(c1, c2, c3);

   if(sellSignal || buySignal) {
      CloseAllPositions();
      DeleteAllOrders();
      
      double entryPrice = SmartPendingOrder ? (patternHigh + patternLow)/2 : 
                        (sellSignal ? c1.high : c1.low);
      
      double sl = CalculateStoploss(sellSignal, patternHigh, patternLow);
      
      if(sellSignal) {
         if(DirectExecute) trade.Sell(LotSize, _Symbol, 0, sl, 0, comment);
         else trade.SellLimit(LotSize, entryPrice, _Symbol, sl, 0, 0, 0, comment);
      }
      else {
         if(DirectExecute) trade.Buy(LotSize, _Symbol, 0, sl, 0, comment);
         else trade.BuyLimit(LotSize, entryPrice, _Symbol, sl, 0, 0, 0, comment);
      }
      
      // Draw pattern rectangle with volume and area display
      DrawPatternWithVolumeArea(c1.time, patternHigh, patternLow, 
                               sellSignal ? SellRectangle : BuyRectangle, 
                               totalVolume, patternArea, patternDelta, hasDelta);
      DrawTriangles(c1, c2, c3);
   }
}



//+------------------------------------------------------------------+
//| Fixed-step trailing stop management                              |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   double step = TrailingDistance * _Point;
   
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(positionInfo.SelectByTicket(ticket) && positionInfo.Magic() == 12345) {
         double currentSl = positionInfo.StopLoss();
         double priceOpen = positionInfo.PriceOpen();
         double newSl = currentSl;
         
         if(positionInfo.PositionType() == POSITION_TYPE_BUY) {
            double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            // Calculate how many steps above entry price
            double steps = MathFloor((currentBid - priceOpen) / step);
            if(steps > 0) {
               newSl = priceOpen + (steps - 1) * step;
               // Ensure we only move SL forward
               if(newSl > currentSl) {
                  trade.PositionModify(ticket, newSl, positionInfo.TakeProfit());
               }
            }
         }
         else if(positionInfo.PositionType() == POSITION_TYPE_SELL) {
            double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            // Calculate how many steps below entry price
            double steps = MathFloor((priceOpen - currentAsk) / step);
            if(steps > 0) {
               newSl = priceOpen - (steps - 1) * step;
               // Ensure we only move SL forward
               if(newSl < currentSl) {
                  trade.PositionModify(ticket, newSl, positionInfo.TakeProfit());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check sell conditions                                            |
//+------------------------------------------------------------------+
bool CheckSellCondition(const MqlRates &c1, const MqlRates &c2, const MqlRates &c3)
{
   if(c1.close > c1.open) // First candle bullish
   {
      if(c2.open > c2.close)
      {
         if(c3.close < c1.low && c3.close < c2.low) // Third candle breaks lows
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check buy conditions                                             |
//+------------------------------------------------------------------+
bool CheckBuyCondition(const MqlRates &c1, const MqlRates &c2, const MqlRates &c3)
{
   if(c1.close < c1.open) // First candle bearish
   {
      if(c2.close > c2.open)
      {
         if(c3.close > c1.high && c3.close > c2.high) // Third candle breaks highs
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calculate stoploss                                               |
//+------------------------------------------------------------------+
double CalculateStoploss(bool isSell, double patternHigh, double patternLow)
{
   if(UnitStoploss) {
      return isSell ? patternHigh + InitialStoplossUnit * _Point : 
                    patternLow - InitialStoplossUnit * _Point;
   }
   return isSell ? patternHigh : patternLow;
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                        |
//+------------------------------------------------------------------+
void DeleteAllOrders()
{
   for(int i = OrdersTotal()-1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
         OrderGetInteger(ORDER_MAGIC) == 12345 &&
         (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP ||
          OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)) {
         trade.OrderDelete(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(positionInfo.SelectByTicket(ticket) && 
         positionInfo.Symbol() == _Symbol && 
         positionInfo.Magic() == 12345) {
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw pattern rectangle with volume, area and delta display       |
//+------------------------------------------------------------------+
void DrawPatternWithVolumeArea(datetime startTime, double high, double low, 
                              color clr, long volume, double areaPoints,
                              long patternDelta, bool hasDelta)
{
   string rectName = "Pattern_"+IntegerToString(startTime);
   datetime endTime = startTime + 3 * PeriodSeconds(_Period);

   // Create or update rectangle
   if(!ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, startTime, low, endTime, high)) {
      ObjectMove(0, rectName, 0, startTime, low);
      ObjectMove(0, rectName, 1, endTime, high);
   }
   
   ObjectSetInteger(0, rectName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
   ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
   
   // Create info label above rectangle
   string labelName = "PatternInfo_"+IntegerToString(startTime);
   double labelPrice = high + (high - low) * 0.1; // 10% above rectangle
   
   string labelText = "Vol: " + DoubleToString(volume, 0) + 
                     " | Area: " + DoubleToString(areaPoints, 0) + " pts";
                     
   if(hasDelta) {
      labelText += " | Delta: " + IntegerToString(patternDelta);
   }
   
   if(ObjectFind(0, labelName) < 0) {
      ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, labelPrice);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
   } else {
      ObjectMove(0, labelName, 0, startTime, labelPrice);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
   }
}

//+------------------------------------------------------------------+
//| Draw high/low triangles                                          |
//+------------------------------------------------------------------+
void DrawTriangles(const MqlRates &c1, const MqlRates &c2, const MqlRates &c3)
{
   string highTriangleName = "HighTri_"+IntegerToString(c1.time);
   string lowTriangleName = "LowTri_"+IntegerToString(c1.time);
   
   // Create high triangle
   ObjectCreate(0, highTriangleName, OBJ_TRIANGLE, 0, c1.time, c1.high, c2.time, c2.high, c3.time, c3.high);
   ObjectSetInteger(0, highTriangleName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, highTriangleName, OBJPROP_BACK, true);
   ObjectSetInteger(0, highTriangleName, OBJPROP_FILL, true);
   ObjectSetInteger(0, highTriangleName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, highTriangleName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, highTriangleName, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, highTriangleName, OBJPROP_RAY_RIGHT, false);
   
   // Create low triangle
   ObjectCreate(0, lowTriangleName, OBJ_TRIANGLE, 0, c1.time, c1.low, c2.time, c2.low, c3.time, c3.low);
   ObjectSetInteger(0, lowTriangleName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, lowTriangleName, OBJPROP_BACK, true);
   ObjectSetInteger(0, lowTriangleName, OBJPROP_FILL, true);
   ObjectSetInteger(0, lowTriangleName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, lowTriangleName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lowTriangleName, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, lowTriangleName, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check for new day                                                |
//+------------------------------------------------------------------+
bool IsNewDay()
{
   MqlDateTime currTime;
   TimeToStruct(TimeCurrent(), currTime);
   static int lastDay = 0;
   
   if(currTime.day != lastDay) {
      lastDay = currTime.day;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Updated trading hours check with toggle                          |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   if(!UseTradingHours) return true; // Bypass check if disabled
   
   MqlDateTime dtNow;
   TimeCurrent(dtNow);
   
   string startParts[], endParts[];
   if(StringSplit(TradingStartTime, ':', startParts) != 2) return false;
   if(StringSplit(TradingEndTime, ':', endParts) != 2) return false;

   int startHour = (int)StringToInteger(startParts[0]);
   int startMin = (int)StringToInteger(startParts[1]);
   int endHour = (int)StringToInteger(endParts[0]);
   int endMin = (int)StringToInteger(endParts[1]);

   int current = dtNow.hour * 3600 + dtNow.min * 60 + dtNow.sec;
   int start = startHour * 3600 + startMin * 60;
   int end = endHour * 3600 + endMin * 60;

   return (current >= start) && (current <= end);
}
