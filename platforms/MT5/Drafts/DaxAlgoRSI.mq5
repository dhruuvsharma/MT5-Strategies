//+------------------------------------------------------------------+
//|                                                   DaxAlgoRSI.mq5 |
//|                                                     Dhruv Sharma |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input int InpLength = 14;               // RSI Length
input ENUM_MA_METHOD InpSmoType1 = MODE_SMMA;  // RSI MA Type
input ENUM_APPLIED_PRICE InpSrc = PRICE_CLOSE; // Source
input int InpSmooth = 14;               // Signal Smoothing
input ENUM_MA_METHOD InpSmoType2 = MODE_EMA;   // Signal MA Type
input double InpOB = 70.0;              // Overbought Level
input double InpOS = 30.0;              // Oversold Level
input double InpLotSize = 0.1;          // Trade Lot Size
input ulong InpMagicNumber = 123456;    // EA Magic Number

// Global variables
double upper[], lower[], diff[], absDiff[], arsi[], signal[];
double srcArray[];
bool positionOpen = false;
ENUM_POSITION_TYPE currentPositionType = WRONG_VALUE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(lower, true);
   ArraySetAsSeries(diff, true);
   ArraySetAsSeries(absDiff, true);
   ArraySetAsSeries(arsi, true);
   ArraySetAsSeries(signal, true);
   ArraySetAsSeries(srcArray, true);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;
   
   if(!UpdateRSI()) return;
   CheckPositions();
   TradingLogic();
}

//+------------------------------------------------------------------+
//| Update RSI values with error checking                            |
//+------------------------------------------------------------------+
bool UpdateRSI()
{
   // Get source prices
   int copied = CopyClose(_Symbol, _Period, 0, InpLength*3, srcArray);
   if(copied < InpLength*3)
   {
      Print("Not enough historical data! Available: ", copied, " Needed: ", InpLength*3);
      return false;
   }
   ArraySetAsSeries(srcArray, true);

   // Calculate highest/lowest with bounds checking
   int maxIndex = ArrayMaximum(srcArray, 0, InpLength);
   int minIndex = ArrayMinimum(srcArray, 0, InpLength);
   
   if(maxIndex < 0 || maxIndex >= ArraySize(srcArray)) return false;
   if(minIndex < 0 || minIndex >= ArraySize(srcArray)) return false;
   
   double currentUpper = srcArray[maxIndex];
   double currentLower = srcArray[minIndex];
   
   // Update upper/lower arrays safely
   ArrayResize(upper, ArraySize(upper)+1);
   ArrayFill(upper, 0, 1, currentUpper);
   
   ArrayResize(lower, ArraySize(lower)+1);
   ArrayFill(lower, 0, 1, currentLower);

   // Calculate diff safely
   double d = srcArray[0] - (ArraySize(srcArray) > 1 ? srcArray[1] : srcArray[0]);
   double r = currentUpper - currentLower;
   double previousUpper = ArraySize(upper) > 1 ? upper[1] : currentUpper;
   double previousLower = ArraySize(lower) > 1 ? lower[1] : currentLower;
   
   double currentDiff = 0;
   if(currentUpper > previousUpper)       currentDiff = r;
   else if(currentLower < previousLower)  currentDiff = -r;
   else                                   currentDiff = d;
   
   // Update diff arrays
   ArrayResize(diff, ArraySize(diff)+1);
   ArrayFill(diff, 0, 1, currentDiff);
   
   ArrayResize(absDiff, ArraySize(absDiff)+1);
   ArrayFill(absDiff, 0, 1, MathAbs(currentDiff));

   // Calculate ARSI
   if(ArraySize(diff) < InpLength || ArraySize(absDiff) < InpLength)
      return false;
   
   double num = CalculateMA(diff, InpLength, InpSmoType1);
   double den = CalculateMA(absDiff, InpLength, InpSmoType1);
   arsi[0] = den != 0 ? (num/den)*50+50 : 50;

   // Calculate Signal Line
   if(ArraySize(arsi) < InpSmooth) return false;
   signal[0] = CalculateMA(arsi, InpSmooth, InpSmoType2);
   
   return true;
}

//+------------------------------------------------------------------+
//| Manual MA Calculations                                           |
//+------------------------------------------------------------------+
double CalculateSMA(double &array[], int length)
{
   double sum = 0;
   for(int i=0; i<length && i<ArraySize(array); i++)
      sum += array[i];
   return sum/length;
}

double CalculateEMA(double &array[], int length)
{
   double multiplier = 2.0/(length+1);
   double ema = CalculateSMA(array, length);
   for(int i=length; i<ArraySize(array); i++)
      ema = array[i]*multiplier + ema*(1-multiplier);
   return ema;
}

double CalculateSMMA(double &array[], int length)
{
   double smma = CalculateSMA(array, length);
   for(int i=length; i<ArraySize(array); i++)
      smma = (smma*(length-1) + array[i])/length;
   return smma;
}

double CalculateMA(double &array[], int length, ENUM_MA_METHOD maType)
{
   if(ArraySize(array) < length) return 0;
   switch(maType)
   {
      case MODE_SMA:  return CalculateSMA(array, length);
      case MODE_EMA:  return CalculateEMA(array, length);
      case MODE_SMMA: return CalculateSMMA(array, length);
      default: return 0;
   }
}

//+------------------------------------------------------------------+
//| Trading Logic                                                    |
//+------------------------------------------------------------------+
void TradingLogic()
{
   if(ArraySize(arsi) < 2) return;
   
   double currentRSI = arsi[0];
   double prevRSI = arsi[1];
   
   // Close positions at opposite levels
   if(positionOpen)
   {
      if((currentPositionType == POSITION_TYPE_BUY && currentRSI >= InpOB) ||
         (currentPositionType == POSITION_TYPE_SELL && currentRSI <= InpOS))
      {
         CloseAllPositions();
         return;
      }
   }
   
   // Open new positions
   if(!positionOpen)
   {
      if(prevRSI < InpOS && currentRSI >= InpOS) // Buy signal
      {
         ExecuteTrade(ORDER_TYPE_BUY);
         currentPositionType = POSITION_TYPE_BUY;
         positionOpen = true;
      }
      else if(prevRSI > InpOB && currentRSI <= InpOB) // Sell signal
      {
         ExecuteTrade(ORDER_TYPE_SELL);
         currentPositionType = POSITION_TYPE_SELL;
         positionOpen = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Position Management                                              |
//+------------------------------------------------------------------+
void CheckPositions()
{
   positionOpen = PositionSelect(_Symbol) && 
                PositionGetInteger(POSITION_MAGIC) == InpMagicNumber;
}

void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   double price = orderType == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   trade.PositionOpen(_Symbol, orderType, InpLotSize, price, 0, 0);
}

void CloseAllPositions()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         trade.PositionClose(ticket);
      }
   }
   positionOpen = false;
   currentPositionType = WRONG_VALUE;
}