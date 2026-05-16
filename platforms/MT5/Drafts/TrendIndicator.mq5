//+------------------------------------------------------------------+
//|                                               TrendIndicator.mq5 |
//|                                                     Dhruv Sharma |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2

// Inputs
input int    ATR_Period = 14;         // ATR period for volatility
input int    MA_Period = 50;          // MA period for trend
input double BreakoutMultiplier = 1.5; // Multiplier for dynamic levels

// Buffers
double UpperBuffer[], LowerBuffer[];

// Global variables
int    MA_Handle, ATR_Handle;
double MA_Array[], ATR_Array[];

//+------------------------------------------------------------------+
int OnInit() {
  SetIndexBuffer(0, UpperBuffer, INDICATOR_DATA);
  SetIndexBuffer(1, LowerBuffer, INDICATOR_DATA);
  SetIndexLabel(0, "Upper Level");
  SetIndexLabel(1, "Lower Level");
  
  MA_Handle = iMA(_Symbol, PERIOD_H1, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
  ATR_Handle = iATR(_Symbol, PERIOD_H1, ATR_Period);
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, ...) {
  if (CopyBuffer(MA_Handle, 0, 0, rates_total, MA_Array) <= 0) return 0;
  if (CopyBuffer(ATR_Handle, 0, 0, rates_total, ATR_Array) <= 0) return 0;

  for (int i = 0; i < rates_total; i++) {
    // Calculate dynamic levels using ATR-based volatility
    UpperBuffer[i] = High[i] + (ATR_Array[i] * BreakoutMultiplier);
    LowerBuffer[i] = Low[i] - (ATR_Array[i] * BreakoutMultiplier);

    // Multi-timeframe check (e.g., confirm D1 trend)
    double DailyMA = iMA(_Symbol, PERIOD_D1, MA_Period, 0, MODE_SMA, PRICE_CLOSE, i);
    
    // Breakout conditions
    if (Close[i] > UpperBuffer[i] && MA_Array[i] > DailyMA) {
      Alert("BUY Signal at ", UpperBuffer[i]);
      // Trigger new order here (e.g., OrderSend)
    }
    else if (Close[i] < LowerBuffer[i] && MA_Array[i] < DailyMA) {
      Alert("SELL Signal at ", LowerBuffer[i]);
    }
  }
  return(rates_total);
}
//+------------------------------------------------------------------+