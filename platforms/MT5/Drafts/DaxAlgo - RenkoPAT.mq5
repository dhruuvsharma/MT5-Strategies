//+------------------------------------------------------------------+
//|                                           DaxAlgo - RenkoPAT.mq5 |
//|                                                     Dhruv Sharma |
//|                              www.linkedin.com/in/dhruvsharmainfo |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      "www.linkedin.com/in/dhruvsharmainfo"
#property version   "1.60"

#include <Trade\Trade.mqh>
CTrade trade;

input int      BrickSizePoints = 500;       // Brick size in points
input int      TrailingStopBrickSize = 500; // Trailing stop brick size
input double   LotSize         = 0.01;      // Lot size
input bool     UseTrailingStop = true;      // Enable Trailing Stop
input int      TrailingBricks  = 1;         // Trailing Stop bricks (1-5)
input int      EntryBricks     = 2;         // Consecutive bricks for entry (1-5)
input bool     UseTimeFilter   = true;      // Enable Time Filter
input double   TakeProfitPoints = 0;        // Fixed Take Profit in points (0=disable)
input double   InitialStopLossPoints = 0;   // Initial Stop Loss in points (0=use brick-based)

// Time filter inputs for each hour (0-23)
input bool     Hour00 = false; input bool     Hour01 = false; input bool     Hour02 = true;
input bool     Hour03 = true;  input bool     Hour04 = true;  input bool     Hour05 = false;
input bool     Hour06 = true;  input bool     Hour07 = false; input bool     Hour08 = true;
input bool     Hour09 = false; input bool     Hour10 = false; input bool     Hour11 = false;
input bool     Hour12 = false; input bool     Hour13 = true;  input bool     Hour14 = true;
input bool     Hour15 = false; input bool     Hour16 = false; input bool     Hour17 = false;
input bool     Hour18 = true;  input bool     Hour19 = false; input bool     Hour20 = false;
input bool     Hour21 = false; input bool     Hour22 = false; input bool     Hour23 = false;

enum ENUM_RENKO_COLOR {COLOR_NONE, COLOR_GREEN, COLOR_RED};

// Global variables
double         renkoSize;
double         trailingStopSize;
double         lastRenkoClose;
double         currentHigh;
double         currentLow;
double         takeProfitSize;
double         initialStopSize;
bool           timeFilterActive = false;

// Arrays to store Renko brick history
double         renkoBricks[];       // Stores close prices of bricks
int            renkoColors[];       // Stores brick colors (0=none,1=green,2=red)
int            brickCount = 0;
int            maxBricksHistory = 20; // Maximum bricks to remember

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   renkoSize = BrickSizePoints * _Point;
   trailingStopSize = TrailingStopBrickSize * _Point;
   takeProfitSize = TakeProfitPoints * _Point;
   initialStopSize = InitialStopLossPoints * _Point;
   lastRenkoClose = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   currentHigh = lastRenkoClose;
   currentLow = lastRenkoClose;
   
   // Initialize arrays
   ArrayResize(renkoBricks, maxBricksHistory);
   ArrayResize(renkoColors, maxBricksHistory);
   ArrayInitialize(renkoBricks, 0);
   ArrayInitialize(renkoColors, 0);
   
   // Add initial brick
   renkoBricks[0] = lastRenkoClose;
   renkoColors[0] = COLOR_NONE;
   brickCount = 1;
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check time filter
   timeFilterActive = false;
   if(UseTimeFilter)
     {
      CheckTradingHours();
      if(!timeFilterActive)
        {
         CloseAllPositions();
         return;
        }
     }
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Update current high and low
   currentHigh = MathMax(currentHigh, currentBid);
   currentLow = MathMin(currentLow, currentBid);
   
   bool newBrickFormed = false;
   ENUM_RENKO_COLOR newColor = COLOR_NONE;
   
   // Check for green brick formation
   if(currentHigh >= lastRenkoClose + renkoSize)
     {
      newColor = COLOR_GREEN;
      newBrickFormed = true;
     }
   // Check for red brick formation
   else if(currentLow <= lastRenkoClose - renkoSize)
     {
      newColor = COLOR_RED;
      newBrickFormed = true;
     }
   
   if(newBrickFormed)
     {
      // Update last Renko close price
      lastRenkoClose = (newColor == COLOR_GREEN) ? 
                       lastRenkoClose + renkoSize : 
                       lastRenkoClose - renkoSize;
      
      // Reset tracking prices
      currentHigh = lastRenkoClose;
      currentLow = lastRenkoClose;
      
      // Add new brick to history
      AddBrickToHistory(lastRenkoClose, newColor);
      
      // Check if we have enough bricks for trading logic
      if(brickCount > EntryBricks)
        {
         // Check exit conditions (fixed at 2 bricks)
         if(CheckConsecutiveBricks(COLOR_RED, 2))
            CloseAllBuyPositions();
         if(CheckConsecutiveBricks(COLOR_GREEN, 2))
            CloseAllSellPositions();
            
         // Check entry conditions - always allow new entries regardless of previous trades
         if(CheckConsecutiveBricks(COLOR_GREEN, EntryBricks))
           {
            CloseAllSellPositions();
            if(!BuyPositionExists())
              {
               double sl = CalculateStopLoss(true);
               double tp = CalculateTakeProfit(true);
               trade.Buy(LotSize, _Symbol, 0, sl, tp, 
                         StringFormat("%d Green Renko", EntryBricks));
              }
           }
         else if(CheckConsecutiveBricks(COLOR_RED, EntryBricks))
           {
            CloseAllBuyPositions();
            if(!SellPositionExists())
              {
               double sl = CalculateStopLoss(false);
               double tp = CalculateTakeProfit(false);
               trade.Sell(LotSize, _Symbol, 0, sl, tp, 
                          StringFormat("%d Red Renko", EntryBricks));
              }
           }
        }
      
      // Update trailing stops
      if(UseTrailingStop && brickCount > TrailingBricks)
        {
         UpdateTrailingStops();
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate take profit for new position                           |
//+------------------------------------------------------------------+
double CalculateTakeProfit(bool isBuy)
  {
   if(takeProfitSize <= 0) return 0;
   
   double currentPrice = isBuy ? 
        SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
        SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
   return isBuy ? 
        NormalizeDouble(currentPrice + takeProfitSize, _Digits) : 
        NormalizeDouble(currentPrice - takeProfitSize, _Digits);
  }

//+------------------------------------------------------------------+
//| Calculate stop loss for new position                             |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBuy)
  {
   // Use initial stop loss if specified
   if(initialStopSize > 0)
     {
      double currentPrice = isBuy ? 
           SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
           SymbolInfoDouble(_Symbol, SYMBOL_BID);
           
      return isBuy ? 
           NormalizeDouble(currentPrice - initialStopSize, _Digits) : 
           NormalizeDouble(currentPrice + initialStopSize, _Digits);
     }
   
   // Otherwise use brick-based stop loss
   if(brickCount <= TrailingBricks)
      return 0; // Not enough history
   
   double stopLevel = renkoBricks[TrailingBricks];
   
   // For buy positions, add a small buffer below the brick
   if(isBuy)
      stopLevel -= trailingStopSize;
   // For sell positions, add a small buffer above the brick
   else
      stopLevel += trailingStopSize;
      
   return NormalizeDouble(stopLevel, _Digits);
  }

//+------------------------------------------------------------------+
//| Check if current time is allowed for trading                     |
//+------------------------------------------------------------------+
void CheckTradingHours()
  {
   MqlDateTime currentTime;
   TimeCurrent(currentTime);
   
   switch(currentTime.hour)
     {
      case 0:  timeFilterActive = Hour00; break;
      case 1:  timeFilterActive = Hour01; break;
      case 2:  timeFilterActive = Hour02; break;
      case 3:  timeFilterActive = Hour03; break;
      case 4:  timeFilterActive = Hour04; break;
      case 5:  timeFilterActive = Hour05; break;
      case 6:  timeFilterActive = Hour06; break;
      case 7:  timeFilterActive = Hour07; break;
      case 8:  timeFilterActive = Hour08; break;
      case 9:  timeFilterActive = Hour09; break;
      case 10: timeFilterActive = Hour10; break;
      case 11: timeFilterActive = Hour11; break;
      case 12: timeFilterActive = Hour12; break;
      case 13: timeFilterActive = Hour13; break;
      case 14: timeFilterActive = Hour14; break;
      case 15: timeFilterActive = Hour15; break;
      case 16: timeFilterActive = Hour16; break;
      case 17: timeFilterActive = Hour17; break;
      case 18: timeFilterActive = Hour18; break;
      case 19: timeFilterActive = Hour19; break;
      case 20: timeFilterActive = Hour20; break;
      case 21: timeFilterActive = Hour21; break;
      case 22: timeFilterActive = Hour22; break;
      case 23: timeFilterActive = Hour23; break;
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
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
         trade.PositionClose(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| Check consecutive bricks of same color                           |
//+------------------------------------------------------------------+
bool CheckConsecutiveBricks(ENUM_RENKO_COLOR colour, int count)
  {
   if(brickCount < count) return false;
   
   for(int i=0; i<count; i++)
     {
      if(renkoColors[i] != colour)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Add brick to history                                             |
//+------------------------------------------------------------------+
void AddBrickToHistory(double price, ENUM_RENKO_COLOR colour)
  {
   // Shift existing bricks to make room for new one
   for(int i = maxBricksHistory-1; i > 0; i--)
     {
      renkoBricks[i] = renkoBricks[i-1];
      renkoColors[i] = renkoColors[i-1];
     }
   
   // Add new brick at position 0
   renkoBricks[0] = price;
   renkoColors[0] = colour;
   
   // Update brick count
   if(brickCount < maxBricksHistory)
      brickCount++;
  }

//+------------------------------------------------------------------+
//| Update trailing stops for open positions                         |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
  {
   if(brickCount <= TrailingBricks)
      return; // Not enough history
   
   double newStop = renkoBricks[TrailingBricks];
   
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;
      
      double currentSl = PositionGetDouble(POSITION_SL);
      double currentTp = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      
      if(type == POSITION_TYPE_BUY)
        {
         double proposedStop = newStop - trailingStopSize;
         if(proposedStop > currentSl || currentSl == 0)
           {
            trade.PositionModify(ticket, proposedStop, currentTp);
           }
        }
      else if(type == POSITION_TYPE_SELL)
        {
         double proposedStop = newStop + trailingStopSize;
         if(currentSl == 0 || proposedStop < currentSl)
           {
            trade.PositionModify(ticket, proposedStop, currentTp);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Close all buy positions                                          |
//+------------------------------------------------------------------+
void CloseAllBuyPositions()
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         trade.PositionClose(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| Close all sell positions                                         |
//+------------------------------------------------------------------+
void CloseAllSellPositions()
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         trade.PositionClose(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| Check if buy position exists                                     |
//+------------------------------------------------------------------+
bool BuyPositionExists()
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Check if sell position exists                                    |
//+------------------------------------------------------------------+
bool SellPositionExists()
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         return true;
        }
     }
   return false;
  }
//+------------------------------------------------------------------+