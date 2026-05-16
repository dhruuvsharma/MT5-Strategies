//+------------------------------------------------------------------+
//|                                                      DaxAlgo.mq5 |
//|                                                     Dhruv Sharma |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property version   "1.00"
#property strict

// Input parameters
input int EMA_BaseLine = 200;         // BaseLine EMA
input color EMA_BaseLineColor = clrGold; // Color of the BaseLine EMA
input int EMA_BaseLineWidth = 2;      // Width of BaseLine EMA

input int NadarayaWatsonPeriod = 20; // Period for smoothing
input int NadarayaWatsonVolatinityPeriod = 20; // Period for calculating volatility (e.g., standard deviation)
input double NadarayaWatsonVolatinityMultiplier = 0.05; // Reduced Multiplier for the envelope bands (previously 0.1)
input color NadarayaWatsonColor = clrBlue;

input color ChartBackgroundColor = clrWhite;
input color BullCandleColor = clrGreen;
input color BearCandleColor = clrRed;
input color GirdColor = clrSilver;
input color ForeGroundColor = clrBlack;
input color VolumeColor = clrBlue;

// Handle for the EMA indicator
int emaHandle = INVALID_HANDLE;

// Buffers for Nadaraya-Watson
double NadarayaWatson_UpperBuffer[];
double NadarayaWatson_LowerBuffer[];

// Track the previous state of price relative to the EMA
bool wasAboveEMA = false;
datetime lastCandleTime = 0; // Track the last candle's open time

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Delete all indicators from the main chart window
   int indicator_count = ChartIndicatorsTotal(0, 0);
   for (int i = indicator_count - 1; i >= 0; i--)
   {
      string indicator_name = ChartIndicatorName(0, 0, i);
      if (ChartIndicatorDelete(0, 0, indicator_name))
      {
         Print("Deleted indicator: ", indicator_name);
      }
      else
      {
         Print("Failed to delete indicator: ", indicator_name, " Error: ", GetLastError());
      }
   }

   // Set Chart appearance
   SetChartAppearance();

   // Create the EMA indicator
   emaHandle = iMA(NULL, 0, EMA_BaseLine, 0, MODE_EMA, PRICE_CLOSE);
   if (emaHandle == INVALID_HANDLE)
   {
      Print("Failed to create EMA indicator!");
      return INIT_FAILED;
   }

   // Add the EMA to the chart
   if (!ChartIndicatorAdd(0, 0, emaHandle))
   {
      Print("Failed to add EMA indicator to the chart!");
      return INIT_FAILED;
   }
   
   // Initialize buffers for Nadaraya-Watson
   ArraySetAsSeries(NadarayaWatson_UpperBuffer, true);
   ArraySetAsSeries(NadarayaWatson_LowerBuffer, true);
   
   Print("EMA indicator added successfully.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release the EMA indicator handle
   if (emaHandle != INVALID_HANDLE)
   {
      IndicatorRelease(emaHandle);
   }

   Print("EMA indicator and drawings removed.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Ensure the EMA handle is valid
   if (emaHandle == INVALID_HANDLE)
   {
      Print("EMA handle is invalid. Cannot calculate EMA.");
      return;
   }

   // Get the current candle's open time
   datetime currentCandleTime = iTime(NULL, 0, 0);
   
   // Execute logic only when a new candle forms
   if(currentCandleTime > lastCandleTime)
   {
      lastCandleTime = currentCandleTime; // Update the last candle time
      double emaValues[];
      if (CopyBuffer(emaHandle, 0, 0, 1, emaValues) <= 0)
      {
         Print("Failed to copy EMA values. Error: ", GetLastError());
         return;
      }
   
      // Monitor price action relative to the EMA
      double currentEMA = emaValues[0]; // Get the current EMA value
      double lastClose = iClose(NULL, 0, 1); // Last closed candle price
      double previousClose = iClose(NULL, 0, 2); // Previous closed candle price
   
      // Detect crossover and print only once per event
      if (previousClose <= currentEMA && lastClose > currentEMA)
      {
         Print("BUY: Price crossed above the EMA.");
         wasAboveEMA = true; // Update the state
      }
      else if (previousClose >= currentEMA && lastClose < currentEMA)
      {
         Print("SELL: Price crossed below the EMA.");
         wasAboveEMA = false; // Update the state
      }
      
      // Calculate and plot Nadaraya-Watson Envelope
      CalculateNadarayaWatsonEnvelope();
   }
}

//+------------------------------------------------------------------+
//| Function to calculate Nadaraya-Watson Envelope                  |
//+------------------------------------------------------------------+
void CalculateNadarayaWatsonEnvelope()
{
   int bars = iBars(NULL, 0);
   if (bars < NadarayaWatsonPeriod) return;

   // Resize buffers if necessary
   ArrayResize(NadarayaWatson_UpperBuffer, bars);
   ArrayResize(NadarayaWatson_LowerBuffer, bars);

   for (int i = 0; i < NadarayaWatsonPeriod; i++)
   {
      double numerator = 0.0, denominator = 0.0;
      double volatility = 0.0;
      
      // Calculate the weighted average (Nadaraya-Watson kernel smoothing)
      for (int j = 0; j < NadarayaWatsonPeriod; j++)
      {
         double distance = MathAbs(iClose(NULL, 0, i - j) - iClose(NULL, 0, i));
         double weight = MathExp(-MathPow(distance / 2.0, 2)); // Gaussian kernel function

         numerator += weight * iClose(NULL, 0, i - j);
         denominator += weight;
      }

      // Smoothed value (weighted average)
      double smoothedValue = numerator / denominator;

      // Calculate volatility (standard deviation) over the given period
      double sumSqDiff = 0.0;
      for (int j = 0; j < NadarayaWatsonVolatinityPeriod; j++)
      {
         sumSqDiff += MathPow(iClose(NULL, 0, i - j) - smoothedValue, 2);
      }
      volatility = MathSqrt(sumSqDiff / NadarayaWatsonVolatinityPeriod);

      // Create the upper and lower bands
      NadarayaWatson_UpperBuffer[i] = smoothedValue + (volatility * NadarayaWatsonVolatinityMultiplier);
      NadarayaWatson_LowerBuffer[i] = smoothedValue - (volatility * NadarayaWatsonVolatinityMultiplier);
   }

   // Debugging to check if the buffers are being populated
   Print("NadarayaWatson_UpperBuffer: ", NadarayaWatson_UpperBuffer[0], " Lower: ", NadarayaWatson_LowerBuffer[0]);

   // Draw on chart
   for (int i = NadarayaWatsonPeriod; i < bars; i++)
   {
      datetime barTime = iTime(NULL, 0, i); // Get the time of the bar

      // Create the upper line
      string upperLineName = "NW_Upper_" + IntegerToString(i);
      ObjectCreate(0, upperLineName, OBJ_TREND, 0, barTime, NadarayaWatson_UpperBuffer[i], barTime + PeriodSeconds(), NadarayaWatson_UpperBuffer[i]);
      ObjectSetInteger(0, upperLineName, OBJPROP_COLOR, clrRed);  // Set color to red
      ObjectSetInteger(0, upperLineName, OBJPROP_WIDTH, 2);       // Set width to 2
      ObjectSetInteger(0, upperLineName, OBJPROP_STYLE, STYLE_SOLID); // Set solid line style

      // Create the lower line
      string lowerLineName = "NW_Lower_" + IntegerToString(i);
      ObjectCreate(0, lowerLineName, OBJ_TREND, 0, barTime, NadarayaWatson_LowerBuffer[i], barTime + PeriodSeconds(), NadarayaWatson_LowerBuffer[i]);
      ObjectSetInteger(0, lowerLineName, OBJPROP_COLOR, clrBlue);  // Set color to blue
      ObjectSetInteger(0, lowerLineName, OBJPROP_WIDTH, 2);       // Set width to 2
      ObjectSetInteger(0, lowerLineName, OBJPROP_STYLE, STYLE_SOLID); // Set solid line style

      // Debugging to confirm line creation
      Print("Created Nadaraya-Watson line at time: ", TimeToString(barTime));
   }
}

//+------------------------------------------------------------------+
//| Function to set chart appearance                                 |
//+------------------------------------------------------------------+
void SetChartAppearance()
{
   // Set background color
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, ChartBackgroundColor);
   // Set grid color
   ChartSetInteger(0, CHART_COLOR_GRID, GirdColor);
   // Set foreground color (for text and labels)
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, ForeGroundColor);
   // Set candle colors
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, BullCandleColor);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, BearCandleColor);
   // Set volume color
   ChartSetInteger(0, CHART_COLOR_VOLUME, VolumeColor);
}
