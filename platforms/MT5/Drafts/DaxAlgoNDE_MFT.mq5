//+------------------------------------------------------------------+
//|                                               DaxAlgoNDE_MFT.mq5 |
//|                                                     Dhruv Sharma |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input int    LookbackWindow = 8;          // Lookback Window
input double RelativeWeight = 8.0;        // Relative Weighting
input int    StartRegressionBar = 25;     // Start Regression Bar
input int    ATRLength = 60;              // ATR Length
input double NearATRFactor = 1.5;         // Near ATR Factor
input double FarATRFactor = 2.0;          // Far ATR Factor
input string StrategyType = "Long Only";  // Strategy Type
input double RiskPercent = 2.0;           // Risk Percentage
input int    MagicNumber = 2024;          // Magic Number

// Indicator buffers
double UpperNearBuffer[], UpperFarBuffer[], LowerNearBuffer[], LowerFarBuffer[];
double ATRBuffer[], EnvelopeCloseBuffer[];

// Global variables
int    totalBars;
double pointValue;
datetime lastBarTime;

//+------------------------------------------------------------------+
//| Custom Nadaraya-Watson Kernel                                    |
//+------------------------------------------------------------------+
double NadarayaWatson(const double &price[], int h, double alpha, int x_0, int index)
{
    double sumWeights = 0.0;
    double sumXWeights = 0.0;
    
    for(int i=0; i<=h; i++)
    {
        int targetIndex = index - (x_0 - i);
        if(targetIndex < 0 || targetIndex >= ArraySize(price)) continue;
        
        double x = price[targetIndex];
        double weight = MathPow(1 + (MathPow(x_0 - i, 2)/(2*alpha*h*h)), -alpha);
        sumWeights += weight;
        sumXWeights += weight * x;
    }
    
    return sumWeights != 0 ? sumXWeights / sumWeights : 0;
}

//+------------------------------------------------------------------+
//| Custom ATR Calculation                                           |
//+------------------------------------------------------------------+
void CalculateATR(int length)
{
    double trueRange[];
    ArrayResize(trueRange, totalBars);
    ArrayInitialize(trueRange, 0);
    
    for(int i=1; i<totalBars; i++)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        double prevClose = iClose(_Symbol, PERIOD_CURRENT, i+1);
        
        double tr1 = high - low;
        double tr2 = MathAbs(high - prevClose);
        double tr3 = MathAbs(low - prevClose);
        trueRange[i] = MathMax(tr1, MathMax(tr2, tr3));
    }
    
    // Calculate RMA
    double sum = 0;
    for(int i=0; i<length; i++) sum += trueRange[i];
    ATRBuffer[0] = sum / length;
    
    for(int i=1; i<totalBars; i++)
        ATRBuffer[i] = (ATRBuffer[i-1]*(length-1) + trueRange[i])/length;
}

//+------------------------------------------------------------------+
//| Initialize Buffers                                               |
//+------------------------------------------------------------------+
void InitializeBuffers()
{
    ArraySetAsSeries(UpperNearBuffer, true);
    ArraySetAsSeries(UpperFarBuffer, true);
    ArraySetAsSeries(LowerNearBuffer, true);
    ArraySetAsSeries(LowerFarBuffer, true);
    ArraySetAsSeries(ATRBuffer, true);
    ArraySetAsSeries(EnvelopeCloseBuffer, true);
    
    ArrayResize(UpperNearBuffer, totalBars);
    ArrayResize(UpperFarBuffer, totalBars);
    ArrayResize(LowerNearBuffer, totalBars);
    ArrayResize(LowerFarBuffer, totalBars);
    ArrayResize(ATRBuffer, totalBars);
    ArrayResize(EnvelopeCloseBuffer, totalBars);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    totalBars = Bars(_Symbol, PERIOD_CURRENT);
    
    InitializeBuffers();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Main Calculation Function                                        |
//+------------------------------------------------------------------+
void CalculateIndicators()
{
    double logClose[];
    ArrayResize(logClose, totalBars);
    
    // Calculate logarithmic prices
    for(int i=0; i<totalBars; i++)
        logClose[i] = MathLog(iClose(_Symbol, PERIOD_CURRENT, i));
    
    // Calculate Nadaraya-Watson envelopes
    for(int i=StartRegressionBar; i<totalBars; i++)
    {
        EnvelopeCloseBuffer[i] = NadarayaWatson(logClose, LookbackWindow, RelativeWeight, StartRegressionBar, i);
        
        double upperFar = EnvelopeCloseBuffer[i] + FarATRFactor * ATRBuffer[i];
        double upperNear = EnvelopeCloseBuffer[i] + NearATRFactor * ATRBuffer[i];
        double lowerNear = EnvelopeCloseBuffer[i] - NearATRFactor * ATRBuffer[i];
        double lowerFar = EnvelopeCloseBuffer[i] - FarATRFactor * ATRBuffer[i];
        
        UpperNearBuffer[i] = upperNear;
        UpperFarBuffer[i] = upperFar;
        LowerNearBuffer[i] = lowerNear;
        LowerFarBuffer[i] = lowerFar;
    }
}

//+------------------------------------------------------------------+
//| Trading Logic                                                    |
//+------------------------------------------------------------------+
void CheckForSignals()
{
    datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentTime == lastBarTime) return;
    
    double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
    double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
    
    double currentUpperNear = UpperNearBuffer[0];
    double prevUpperNear = UpperNearBuffer[1];
    double currentLowerNear = LowerNearBuffer[0];
    double prevLowerNear = LowerNearBuffer[1];
    
    // Long Conditions
    bool longEntry = (prevClose <= prevLowerNear) && (currentClose > currentLowerNear);
    bool longExit = (prevClose >= prevUpperNear) && (currentClose < currentUpperNear);
    
    // Short Conditions
    bool shortEntry = (prevClose >= prevUpperNear) && (currentClose < currentUpperNear);
    bool shortExit = (prevClose <= prevLowerNear) && (currentClose > currentLowerNear);
    
    // Execute trades
    if(StrategyType == "Long Only" || StrategyType == "Long/Short")
    {
        if(longEntry && !PositionExists(POSITION_TYPE_BUY))
            ExecuteTrade(ORDER_TYPE_BUY);
            
        if(longExit && PositionExists(POSITION_TYPE_BUY))
            ClosePosition(POSITION_TYPE_BUY);
    }
    
    if(StrategyType == "Long/Short")
    {
        if(shortEntry && !PositionExists(POSITION_TYPE_SELL))
            ExecuteTrade(ORDER_TYPE_SELL);
            
        if(shortExit && PositionExists(POSITION_TYPE_SELL))
            ClosePosition(POSITION_TYPE_SELL);
    }
    
    lastBarTime = currentTime;
}

//+------------------------------------------------------------------+
//| Position Check                                                   |
//+------------------------------------------------------------------+
bool PositionExists(ENUM_POSITION_TYPE type)
{
    return PositionSelectByTicket(PositionGetTicket(type)) ? true : false;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
    double price = orderType == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lotSize = CalculateLotSize();
    
    trade.PositionOpen(_Symbol, orderType, lotSize, price, 0, 0);
}

//+------------------------------------------------------------------+
//| Close Position                                                   |
//+------------------------------------------------------------------+
void ClosePosition(ENUM_POSITION_TYPE type)
{
    ulong ticket = PositionGetTicket(type);
    if(ticket > 0) trade.PositionClose(ticket);
}

//+------------------------------------------------------------------+
//| Calculate Position Size                                          |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercent / 100);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    return NormalizeDouble(riskAmount / tickValue, 2);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    totalBars = Bars(_Symbol, PERIOD_CURRENT);
    if(totalBars < StartRegressionBar + LookbackWindow + 100) return;
    
    CalculateATR(ATRLength);
    CalculateIndicators();
    CheckForSignals();
    
    // Update chart objects
    UpdateChannelObjects();
}

//+------------------------------------------------------------------+
//| Visual Display                                                   |
//+------------------------------------------------------------------+
void UpdateChannelObjects()
{
    CreateChannel("UpperChannel", UpperNearBuffer[0], UpperFarBuffer[0], clrRed);
    CreateChannel("LowerChannel", LowerNearBuffer[0], LowerFarBuffer[0], clrBlue);
}

void CreateChannel(string name, double upper, double lower, color clr)
{
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, TimeCurrent(), upper, TimeCurrent()-PeriodSeconds()*100, lower);
    
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
}