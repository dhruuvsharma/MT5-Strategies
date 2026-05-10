//+------------------------------------------------------------------+
//|                                                  DeltaFadeEA.mq5 |
//|                                                     Dhruv Sharma |
//|                              www.linkedin.com/in/dhruvsharmainfo |
//+------------------------------------------------------------------+
#property copyright "Dhruv Sharma"
#property version   "3.00"
#property description "Trend-following pullback scalper on XAUUSD. Uses EMA for trend direction, cumulative tick/volume delta for pullback detection, and dynamic Median+MAD thresholds."

#include "Config.mqh"
#include "Market.mqh"
#include "Signal.mqh"
#include "Risk.mqh"
#include "Trade.mqh"
#include "Utils.mqh"

//--- Bar tracking
datetime lastBarTime = 0;

//--- Tester mode flag (set once in OnInit)
bool isTester       = false;
bool isTesterVisual = false;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    isTester       = (bool)MQLInfoInteger(MQL_TESTER);
    isTesterVisual = (bool)MQLInfoInteger(MQL_VISUAL_MODE);

    MarketInit();
    TradeInit();

    lastBarTime = iTime(_Symbol, _Period, 0);

    CalculateDeltas();
    CalculateVolumeFootprint();
    CalculateTicksPerSecond();
    UpdateEMA();
    InitializeAnalysisWindows();

    CalculateDynamicTickThresholds();
    CalculateDynamicVolumeThresholds();

    if(!isTester || isTesterVisual)
    {
        DrawRectangle();
        DrawVolumeFootprintLine();
        DrawThresholdWindows();
    }

    Print("[", EA_NAME, "] v", EA_VERSION, " initialised",
          isTester ? " [TESTER MODE]" : "");
    Print("[", EA_NAME, "] Mode=", TrendFollowing ? "TrendPullback" : "Contrarian",
          "  EMA=", TrendEMAPeriod,
          "  BothDeltas=", RequireBothDeltas,
          "  SlopeConfirm=", RequireSlopeConfirmation,
          "  MaxTrades/Day=", MaxTradesPerDay,
          "  Cooldown=", MinBarsBetweenTrades, " bars");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    MarketDeinit();
    if(!isTester || isTesterVisual)
        CleanupObjects();
    Print("[", EA_NAME, "] deinitialised");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime curBarTime = iTime(_Symbol, _Period, 0);
    bool isNewBar = (curBarTime != lastBarTime);

    if(isNewBar)
    {
        lastBarTime = curBarTime;
        ProcessNewBar();
    }
    else
    {
        if(isTester && !isTesterVisual)
            return;
        ProcessSameBar();
    }

    if(!isTester || isTesterVisual)
        DisplayTimeFilterStatus();

    if(EnableTrading)
        ManagePositions();
}

//+------------------------------------------------------------------+
//| New-bar logic                                                    |
//+------------------------------------------------------------------+
void ProcessNewBar()
{
    // Update bar cooldown counter
    OnNewBarSignal();

    // Recalculate all market data
    CalculateDeltas();
    CalculateVolumeFootprint();
    CalculateTicksPerSecond();
    UpdateEMA();

    if(WindowSize > 1)
    {
        UpdateTickAnalysisWindow(tickDelta[1]);
        UpdateVolumeAnalysisWindow(volumeDelta[1]);
        CalculateDynamicTickThresholds();
        CalculateDynamicVolumeThresholds();
    }

    if(!isTester || isTesterVisual)
        RedrawVisuals();

    if(EnableTrading && IsTradingAllowed())
        EvaluateAndExecute();
}

//+------------------------------------------------------------------+
//| Same-bar (intra-bar) — live / visual-tester only                 |
//+------------------------------------------------------------------+
void ProcessSameBar()
{
    UpdateCurrentCandleDelta();
    UpdateCurrentVolumeFootprint();
    UpdateCurrentTicksPerSecond();

    if(!isTester || isTesterVisual)
        RedrawVisuals();
}

//+------------------------------------------------------------------+
//| Refresh all chart drawings                                       |
//+------------------------------------------------------------------+
void RedrawVisuals()
{
    DrawRectangle();
    DrawVolumeFootprintLine();
    DisplayDeltas();
    UpdateThresholdWindows();
}

//+------------------------------------------------------------------+
//| Check signals then execute if valid                              |
//+------------------------------------------------------------------+
void EvaluateAndExecute()
{
    CheckTradingSignals();

    if(signalLong && !HasLongPosition())
    {
        if(!isTester || isTesterVisual)
            DisplaySignal("LONG — Trend Pullback", clrLime);
        EnterLong();
    }
    if(signalShort && !HasShortPosition())
    {
        if(!isTester || isTesterVisual)
            DisplaySignal("SHORT — Trend Pullback", clrRed);
        EnterShort();
    }
    if(!signalLong && !signalShort)
    {
        if(!isTester || isTesterVisual)
            ObjectDelete(0, "Current_Signal");
    }
}

//+------------------------------------------------------------------+
//| Chart-event handler (never fires in tester)                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        DrawRectangle();
        DisplayDeltas();
        DrawVolumeFootprintLine();
        DisplayTimeFilterStatus();
        DisplayDynamicThresholds();
    }
}
//+------------------------------------------------------------------+
