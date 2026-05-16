//+------------------------------------------------------------------+
//|                                                 SpeedBasedEA.mq5 |
//|                                                     Dhruv Sharma |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//|                          SpeedBasedEA.mq5                        |
//|    Advanced EA using Speed Algo, LSF + Kalman, MTF, Dashboard    |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

//--- input parameters
input int    SpeedPeriod     = 5;
input double SpeedThreshold  = 0.0003;
input int    LSF_Window      = 20;
input double LotSize         = 0.1;
input int    StopLossPips    = 200;
input int    TakeProfitPips  = 400;
input int    TrailStopPips   = 150;
input ENUM_TIMEFRAMES MTF_ConfirmTF = PERIOD_H1;

//--- global variables
double kalman_est = 0;
double kalman_error = 1;
const double kalman_q = 0.00001;
const double kalman_r = 0.001;

//+------------------------------------------------------------------+
//| Calculate price speed                                            |
//+------------------------------------------------------------------+
double GetSpeed(string symbol, ENUM_TIMEFRAMES tf, int shift, int period)
{
   double price_now = iClose(symbol, tf, shift);
   double price_past = iClose(symbol, tf, shift + period);
   return (price_now - price_past) / period;
}

//+------------------------------------------------------------------+
//| LSF slope calculation                                            |
//+------------------------------------------------------------------+
double GetLSFSlope(string symbol, ENUM_TIMEFRAMES tf, int shift, int window)
{
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   for(int i = 0; i < window; i++)
   {
      double price = iClose(symbol, tf, shift + i);
      sumX  += i;
      sumY  += price;
      sumXY += i * price;
      sumX2 += i * i;
   }
   double denominator = window * sumX2 - sumX * sumX;
   if(denominator == 0) return 0;
   double slope = (window * sumXY - sumX * sumY) / denominator;
   return slope;
}

//+------------------------------------------------------------------+
//| Kalman Filter for price smoothing                                |
//+------------------------------------------------------------------+
double KalmanUpdate(double measurement)
{
   kalman_est = kalman_est; // prediction step
   kalman_error += kalman_q;

   double kalman_gain = kalman_error / (kalman_error + kalman_r);
   kalman_est = kalman_est + kalman_gain * (measurement - kalman_est);
   kalman_error = (1 - kalman_gain) * kalman_error;

   return kalman_est;
}

//+------------------------------------------------------------------+
//| Check open position direction                                     |
//+------------------------------------------------------------------+
int GetOpenPositionType()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         return PositionGetInteger(POSITION_TYPE);
      }
   }
   return -1; // No position
}

//+------------------------------------------------------------------+
//| Execute trailing stop                                            |
//+------------------------------------------------------------------+
void UpdateTrailingStop()
{
   if(!PositionSelect(_Symbol)) return;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double new_sl = 0;

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      new_sl = price - TrailStopPips * _Point;
      if(new_sl > sl)
         trade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      new_sl = price + TrailStopPips * _Point;
      if(new_sl < sl)
         trade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
   }
}

//+------------------------------------------------------------------+
//| Draw dashboard with signals                                      |
//+------------------------------------------------------------------+
void DrawDashboard(string signal)
{
   string name = "dashboard";
   string text = "Speed EA\n" + signal;
   int x = 10, y = 30;
   color txt_color = clrWhite;
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txt_color);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Expert Tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   double price = iClose(_Symbol, _Period, 0);
   double kalman = KalmanUpdate(price);
   double speed = GetSpeed(_Symbol, _Period, 0, SpeedPeriod);
   double slope = GetLSFSlope(_Symbol, _Period, 0, LSF_Window);
   double mtf_slope = GetLSFSlope(_Symbol, MTF_ConfirmTF, 0, LSF_Window);

   bool longSignal = (speed > SpeedThreshold && slope > 0 && mtf_slope > 0);
   bool shortSignal = (speed < -SpeedThreshold && slope < 0 && mtf_slope < 0);

   string sigtext = StringFormat("Speed: %.5f | Slope: %.5f\nKalman: %.5f\nMTF: %.5f", speed, slope, kalman, mtf_slope);
   DrawDashboard(sigtext);

   int positionType = GetOpenPositionType();

   if(longSignal && positionType != POSITION_TYPE_BUY)
   {
      if(positionType != -1) trade.PositionClose(_Symbol);
      trade.Buy(LotSize, _Symbol, price, price - StopLossPips * _Point, price + TakeProfitPips * _Point);
   }
   else if(shortSignal && positionType != POSITION_TYPE_SELL)
   {
      if(positionType != -1) trade.PositionClose(_Symbol);
      trade.Sell(LotSize, _Symbol, price, price + StopLossPips * _Point, price - TakeProfitPips * _Point);
   }

   UpdateTrailingStop();
}
