//+------------------------------------------------------------------+
//|                                        DaxAlgo - StratTagger.mq5 |
//|                                                     Dhruv Sharma |
//|                              www.linkedin.com/in/dhruvsharmainfo |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      "www.linkedin.com/in/dhruvsharmainfo"
#property version   "1.00"
#property strict

input double Lots         = 0.1;          // Trade volume
input int    SL_Points    = 2000;         // Stop Loss in points
input int    TP_Points    = 2000;         // Take Profit in points
input ulong  MagicNumber  = 123456;       // Unique EA identifier
input bool   OrderManagement = true;      // Enable smart order management
input bool   UseTradingHours = true;      // Enable trading hours filter
input string  TradingStartTime = "13:00";  // Start time (HH:MM)
input string  TradingEndTime = "16:00";    // End time (HH:MM)
datetime lastProcessedTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   lastProcessedTime = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjects("HighLine");
   DeleteObjects("LowLine");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

   if(UseTradingHours && !IsWithinTradingHours()) return;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   
   if(currentTime == lastProcessedTime) return;
   lastProcessedTime = currentTime;
   
   if(Bars(_Symbol, _Period) < 4) return;

   // Get price data
   double H1,H2,H3,L1,L2,L3;
   datetime tH1,tH2,tH3,tL1,tL2,tL3;
   GetCandleData(H1,H2,H3,L1,L2,L3,tH1,tH2,tH3,tL1,tL2,tL3);

   // Calculate conditions
   bool isHighGreen = IsAboveLine(H2, H3, tH3, H1, tH1);
   bool isLowGreen = IsAboveLine(L2, L3, tL3, L1, tL1);

   // Update drawings
   UpdateDrawings(isHighGreen, isLowGreen, tH1, H1, tH2, H2, tH3, H3, tL1, L1, tL2, L2, tL3, L3, currentTime); // Add current candle time
   // Order management
   ENUM_ORDER_TYPE signalType = WRONG_VALUE;
   double entryPrice = 0;
   
   if(isHighGreen && isLowGreen)
   {
      signalType = ORDER_TYPE_SELL_LIMIT;
      entryPrice = H2;
   }
   else if(!isHighGreen && !isLowGreen)
   {
      signalType = ORDER_TYPE_BUY_LIMIT;
      entryPrice = L2;
   }
   
   if(signalType != WRONG_VALUE)
      ProcessSignal(signalType, entryPrice);
}

//+------------------------------------------------------------------+
//| Process trade signals with enhanced management                   |
//+------------------------------------------------------------------+
void ProcessSignal(ENUM_ORDER_TYPE type, double price)
{
   if(OrderManagement)
   {
      // Check for existing position
      if(HasActivePosition(type))
      {
         Print("Active position exists - skipping new order");
         return;
      }
      
      // Delete existing pending orders of same type
      DeletePendingOrdersByType(type);
   }
   
   // Calculate SL/TP
   double sl = (type == ORDER_TYPE_BUY_LIMIT) ? 
               price - SL_Points * _Point : 
               price + SL_Points * _Point;
   double tp = (type == ORDER_TYPE_BUY_LIMIT) ? 
               price + TP_Points * _Point : 
               price - TP_Points * _Point;
   
   SendPendingOrder(type, price, sl, tp);
}

//+------------------------------------------------------------------+
//| Check if price is above trend line                               |
//+------------------------------------------------------------------+
bool IsAboveLine(double testPrice, double startPrice, datetime startTime, 
                double endPrice, datetime endTime)
{
   if(startTime == endTime) return false;
   double slope = (endPrice - startPrice) / (endTime - startTime);
   double linePrice = startPrice + slope * (endTime - startTime);
   return testPrice > linePrice;
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

//+------------------------------------------------------------------+
//| Delete pending orders by type                                    |
//+------------------------------------------------------------------+
void DeletePendingOrdersByType(ENUM_ORDER_TYPE type)
{
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && 
         OrderGetInteger(ORDER_MAGIC) == MagicNumber &&
         OrderGetInteger(ORDER_TYPE) == type)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         request.action = TRADE_ACTION_REMOVE;
         request.order = ticket;
         
         if(!OrderSend(request, result))
            Print("Failed to delete order ", ticket, " Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Updated drawing functions                                        |
//+------------------------------------------------------------------+
void UpdateDrawings(bool isHighGreen, bool isLowGreen,
                   datetime tH1, double H1, datetime tH2, double H2, datetime tH3, double H3,
                   datetime tL1, double L1, datetime tL2, double L2, datetime tL3, double L3,
                   datetime currentBarTime)
{
   DeleteObjects("HighLine");
   DeleteObjects("LowLine");
   
   // Draw High triangle with time-based unique names
   color highColor = isHighGreen ? clrLimeGreen : clrIndianRed;
   DrawTriangle("HighLine_"+TimeToString(currentBarTime), 
               tH1, H1, tH2, H2, tH3, H3, highColor);
   
   // Draw Low triangle with time-based unique names
   color lowColor = isLowGreen ? clrLimeGreen : clrIndianRed;
   DrawTriangle("LowLine_"+TimeToString(currentBarTime), 
               tL1, L1, tL2, L2, tL3, L3, lowColor);
}

//+------------------------------------------------------------------+
//| Check for active positions                                       |
//+------------------------------------------------------------------+
bool HasActivePosition(ENUM_ORDER_TYPE orderType)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Convert order type to position type
         if((orderType == ORDER_TYPE_BUY_LIMIT && posType == POSITION_TYPE_BUY) ||
            (orderType == ORDER_TYPE_SELL_LIMIT && posType == POSITION_TYPE_SELL))
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Delete drawing objects                                           |
//+------------------------------------------------------------------+
void DeleteObjects(string prefix)
{
   for(int i = ObjectsTotal(0)-1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Modified DrawTriangle function                                   |
//+------------------------------------------------------------------+
void DrawTriangle(string prefix, datetime t1, double p1, datetime t2, double p2, datetime t3, double p3, color clr)
{
   CreateTrendLine(prefix+"_1", t1, p1, t2, p2, clr);
   CreateTrendLine(prefix+"_2", t2, p2, t3, p3, clr);
   CreateTrendLine(prefix+"_3", t3, p3, t1, p1, clr);
}

//+------------------------------------------------------------------+
//| Enhanced CreateTrendLine function                                |
//+------------------------------------------------------------------+
void CreateTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color clr)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Send pending order                                               |
//+------------------------------------------------------------------+
void SendPendingOrder(ENUM_ORDER_TYPE type, double price, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = Lots;
   request.type = type;
   request.price = NormalizeDouble(price, _Digits);
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.deviation = 5;
   request.magic = MagicNumber;
   request.type_filling = ORDER_FILLING_FOK;
   
   if(!OrderSend(request, result))
      Print("OrderSend failed: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Get candle data in single call                                   |
//+------------------------------------------------------------------+
void GetCandleData(double &h1, double &h2, double &h3,
                   double &l1, double &l2, double &l3,
                   datetime &t1, datetime &t2, datetime &t3,
                   datetime &t4, datetime &t5, datetime &t6)
{
   h1 = iHigh(_Symbol, _Period, 3);
   h2 = iHigh(_Symbol, _Period, 2);
   h3 = iHigh(_Symbol, _Period, 1);
   l1 = iLow(_Symbol, _Period, 3);
   l2 = iLow(_Symbol, _Period, 2);
   l3 = iLow(_Symbol, _Period, 1);
   
   t1 = iTime(_Symbol, _Period, 3);
   t2 = iTime(_Symbol, _Period, 2);
   t3 = iTime(_Symbol, _Period, 1);
   t4 = t1;  // tL1 same as tH1
   t5 = t2;  // tL2 same as tH2
   t6 = t3;  // tL3 same as tH3
}

