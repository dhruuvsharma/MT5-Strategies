//+------------------------------------------------------------------+
//|                                             RenkoDisplay.mq5     |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1
#property indicator_label1  "Renko"
#property indicator_type1   DRAW_CANDLES
#property indicator_color1  clrGreen, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

input int      BrickSizePoints = 500;    // Brick size in points

double         RenkoOpen[];
double         RenkoHigh[];
double         RenkoLow[];
double         RenkoClose[];
double         renkoSize;
double         lastBrickClose;
bool           newBarFormed;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator properties
   SetIndexBuffer(0, RenkoOpen, INDICATOR_DATA);
   SetIndexBuffer(1, RenkoHigh, INDICATOR_DATA);
   SetIndexBuffer(2, RenkoLow, INDICATOR_DATA);
   SetIndexBuffer(3, RenkoClose, INDICATOR_DATA);
   
   // Set as series for easier access
   ArraySetAsSeries(RenkoOpen, true);
   ArraySetAsSeries(RenkoHigh, true);
   ArraySetAsSeries(RenkoLow, true);
   ArraySetAsSeries(RenkoClose, true);
   
   // Initialize variables
   renkoSize = BrickSizePoints * _Point;
   newBarFormed = false;
   
   // Set initial brick
   lastBrickClose = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Check if new bar has formed
   static datetime lastBarTime = 0;
   datetime currentBarTime = time[0];
   if(currentBarTime != lastBarTime)
   {
      newBarFormed = true;
      lastBarTime = currentBarTime;
   }
   
   // Get current price
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // For new bars, create a brick at the same level
   if(newBarFormed)
   {
      // Shift previous values
      for(int i = ArraySize(RenkoOpen)-1; i > 0; i--)
      {
         RenkoOpen[i] = RenkoOpen[i-1];
         RenkoHigh[i] = RenkoHigh[i-1];
         RenkoLow[i] = RenkoLow[i-1];
         RenkoClose[i] = RenkoClose[i-1];
      }
      
      // Create new brick at same level
      RenkoOpen[0] = lastBrickClose;
      RenkoClose[0] = lastBrickClose;
      RenkoHigh[0] = lastBrickClose;
      RenkoLow[0] = lastBrickClose;
      
      newBarFormed = false;
   }
   
   // Update current brick with price movement
   double currentHigh = MathMax(RenkoHigh[0], currentBid);
   double currentLow = MathMin(RenkoLow[0], currentBid);
   
   // Check for new brick formation
   if(currentHigh >= lastBrickClose + renkoSize)
   {
      // Green brick
      RenkoOpen[0] = lastBrickClose;
      RenkoClose[0] = lastBrickClose + renkoSize;
      RenkoHigh[0] = RenkoClose[0];
      RenkoLow[0] = RenkoOpen[0];
      lastBrickClose = RenkoClose[0];
   }
   else if(currentLow <= lastBrickClose - renkoSize)
   {
      // Red brick
      RenkoOpen[0] = lastBrickClose;
      RenkoClose[0] = lastBrickClose - renkoSize;
      RenkoHigh[0] = RenkoOpen[0];
      RenkoLow[0] = RenkoClose[0];
      lastBrickClose = RenkoClose[0];
   }
   else
   {
      // Update wicks without changing brick body
      RenkoHigh[0] = currentHigh;
      RenkoLow[0] = currentLow;
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+