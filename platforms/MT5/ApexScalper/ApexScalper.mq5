//+------------------------------------------------------------------+
//| ApexScalper.mq5 — APEX_SCALPER Expert Advisor                   |
//| Entry points only. No logic lives here.                          |
//| All logic delegated to module classes.                           |
//|                                                                  |
//| Build order: See INSTRUCTIONS.md                                 |
//| Module status: See MEMORY.md                                     |
//+------------------------------------------------------------------+
#property copyright "APEX_SCALPER"
#property version   "1.00"
#property strict

//--- Core includes (always first)
#include "Core/Defines.mqh"
#include "Core/Inputs.mqh"
#include "Core/State.mqh"
#include "Core/EventBus.mqh"

//--- Utility layer (Session 2) ✓ STABLE
#include "Utils/RingBuffer.mqh"
#include "Utils/MathUtils.mqh"
#include "Utils/TimeUtils.mqh"
#include "Utils/StringUtils.mqh"

//--- Data layer pt1 (Session 3) ✓ STABLE
#include "Data/TickCollector.mqh"
#include "Data/CandleBuilder.mqh"
//--- Data layer pt2 (Session 4) ✓ STABLE
#include "Data/FootprintBuilder.mqh"
#include "Data/OrderBookSnapshot.mqh"
//--- Data layer pt3 (Session 5) ✓ STABLE
#include "Data/VolumeProfile.mqh"
#include "Data/WindowManager.mqh"

//--- Signal layer (Session 6) ✓ STABLE
#include "Signals/SignalBase.mqh"
#include "Signals/DeltaSignal.mqh"
#include "Signals/VPINSignal.mqh"
#include "Signals/OBISignal.mqh"
#include "Signals/FootprintSignal.mqh"
#include "Signals/AbsorptionSignal.mqh"
#include "Signals/HVPSignal.mqh"
#include "Signals/TapeSpeedSignal.mqh"
#include "Signals/VPOCSignal.mqh"
#include "Signals/SpreadSignal.mqh"

//--- Engine layer (Session 7) ✓ STABLE
#include "Engine/SignalDecayManager.mqh"
#include "Engine/ConflictFilter.mqh"
#include "Engine/ScoringEngine.mqh"
#include "Engine/RegimeClassifier.mqh"
#include "Engine/ConfirmationGate.mqh"

//--- Execution layer (Session 8) ✓ STABLE
#include "Execution/StopLossEngine.mqh"
#include "Execution/TakeProfitEngine.mqh"
#include "Execution/TradeManager.mqh"
#include "Execution/PositionTracker.mqh"

//--- Risk layer (Session 9) ✓ STABLE
#include "Risk/SessionFilter.mqh"
#include "Risk/SpreadFilter.mqh"
#include "Risk/NewsFilter.mqh"
#include "Risk/RiskManager.mqh"

//--- UI layer (Session 10) ✓ STABLE
#include "UI/PanelTheme.mqh"
#include "UI/SignalLEDs.mqh"
#include "UI/DashboardPanel.mqh"
//--- UI renderers (Session 11) ✓ STABLE
#include "UI/FootprintRenderer.mqh"
#include "UI/HVPRenderer.mqh"
#include "UI/OBRenderer.mqh"

//--- Logging layer (Session 12) ✓ STABLE
#include "Logging/SessionLogger.mqh"
#include "Logging/TradeLogger.mqh"
#include "Logging/SignalLogger.mqh"

//+------------------------------------------------------------------+
//| Global module instances                                          |
//+------------------------------------------------------------------+
CTickCollector  g_TickCollector;    // Session 3 ✓
CCandleBuilder  g_CandleBuilder;    // Session 3 ✓
CFootprintBuilder   g_FootprintBuilder;  // Session 4 ✓
COrderBookSnapshot  g_OrderBook;         // Session 4 ✓
CWindowManager      g_WindowManager;     // Session 5 ✓  (owns CVolumeProfile internally)
CDeltaSignal      g_DeltaSignal;      // Session 6 ✓
CVPINSignal       g_VPINSignal;       // Session 6 ✓
COBISignal        g_OBISignal;        // Session 6 ✓
CFootprintSignal  g_FootprintSignal;  // Session 6 ✓
CAbsorptionSignal g_AbsorptionSignal; // Session 6 ✓
CHVPSignal        g_HVPSignal;        // Session 6 ✓
CTapeSpeedSignal  g_TapeSpeedSignal;  // Session 6 ✓
CVPOCSignal       g_VPOCSignal;       // Session 6 ✓
CSpreadSignal     g_SpreadSignal;     // Session 6 ✓
CSignalDecayManager g_DecayManager;    // Session 7 ✓
CConflictFilter     g_ConflictFilter;  // Session 7 ✓
CScoringEngine      g_ScoringEngine;   // Session 7 ✓
CRegimeClassifier   g_Regime;          // Session 7 ✓
CConfirmationGate   g_Gate;            // Session 7 ✓
CStopLossEngine    g_SLEngine;         // Session 8 ✓
CTakeProfitEngine  g_TPEngine;         // Session 8 ✓
CTradeManager      g_TradeManager;     // Session 8 ✓
CPositionTracker   g_PositionTracker;  // Session 8 ✓
CSessionFilter     g_SessionFilter;    // Session 9 ✓
CSpreadFilter      g_SpreadFilter;     // Session 9 ✓
CNewsFilter        g_NewsFilter;       // Session 9 ✓
CRiskManager       g_RiskManager;      // Session 9 ✓
CDashboardPanel    g_Dashboard;        // Session 10 ✓
CFootprintRenderer g_FPRenderer;       // Session 11 ✓
CHVPRenderer       g_HVPRenderer;      // Session 11 ✓
COBRenderer        g_OBRenderer;       // Session 11 ✓
CSessionLogger     g_SessionLogger;    // Session 12 ✓ (declare before TradeLogger)
CTradeLogger       g_TradeLogger;      // Session 12 ✓
CSignalLogger      g_SignalLogger;     // Session 12 ✓

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Record session start time
    g_SessionStartTime   = TimeCurrent();
    g_LastOBSnapshotTime = 0;
    g_LastOBSnapshotMs   = 0;
    g_BarsProcessed      = 0;
    g_BarsSinceLastTrade = 999;
    g_DailyPnL           = 0.0;
    g_PeakEquity         = AccountInfoDouble(ACCOUNT_EQUITY);
    g_LastBarTime        = 0;
    g_TotalTrades        = 0;
    g_WinningTrades      = 0;

    //--- Initialize event bus
    if(!g_EventBus.Initialize())
    {
        Print("APEX: EventBus initialization failed");
        return INIT_FAILED;
    }

    //--- Validate signal weights sum to 1.0
    double weight_sum = InpWeightDelta + InpWeightVPIN + InpWeightOBI + InpWeightOBIDeep
                      + InpWeightFootprint + InpWeightHVP + InpWeightAbsorption + InpWeightTapeSpeed;
    if(MathAbs(weight_sum - 1.0) > 0.001)
    {
        PrintFormat("APEX WARNING: Signal weights sum to %.4f, not 1.0. Will normalize at runtime.", weight_sum);
    }

    //--- Validate window size
    if(InpWindowSize < 5)
    {
        Print("APEX: InpWindowSize must be >= 5");
        return INIT_FAILED;
    }

    //--- Validate max positions
    if(InpMaxOpenPositions < 1 || InpMaxOpenPositions > APEX_MAX_OPEN_POSITIONS)
    {
        PrintFormat("APEX: InpMaxOpenPositions must be 1-%d", APEX_MAX_OPEN_POSITIONS);
        return INIT_FAILED;
    }

    //--- Run utility unit tests (remove or guard with #ifdef DEBUG in production)
    MathUtils_RunTests();
    TimeUtils_RunTests();
    StringUtils_RunTests();

    //--- Subscribe to order book events for current symbol
    if(!MarketBookAdd(Symbol()))
    {
        Print("APEX WARNING: MarketBookAdd failed — OBI signals will be unavailable");
    }

    PrintFormat("APEX_SCALPER initialized on %s %s | Magic: %d",
                Symbol(), EnumToString(InpTimeframe), InpMagicNumber);

    //--- Session 3: initialize tick collector and candle builder
    if(!g_TickCollector.Initialize())
    {
        Print("APEX: TickCollector initialization failed");
        return INIT_FAILED;
    }
    if(!g_CandleBuilder.Initialize(InpWindowSize))
    {
        Print("APEX: CandleBuilder initialization failed");
        return INIT_FAILED;
    }

    //--- Session 4: initialize footprint builder and order book
    if(!g_FootprintBuilder.Initialize(InpWindowSize))
    {
        Print("APEX: FootprintBuilder initialization failed");
        return INIT_FAILED;
    }
    if(!g_OrderBook.Initialize())
    {
        Print("APEX: OrderBookSnapshot initialization failed");
        return INIT_FAILED;
    }

    //--- Session 5: initialize window manager (takes pointers to builders)
    if(!g_WindowManager.Initialize(&g_CandleBuilder, &g_FootprintBuilder, InpWindowSize))
    {
        Print("APEX: WindowManager initialization failed");
        return INIT_FAILED;
    }

    //--- Session 6: initialize all signal modules
    if(!g_DeltaSignal.Initialize(&g_WindowManager))       { Print("APEX: DeltaSignal init failed");      return INIT_FAILED; }
    if(!g_VPINSignal.Initialize(&g_TickCollector))        { Print("APEX: VPINSignal init failed");       return INIT_FAILED; }
    if(!g_OBISignal.Initialize(&g_OrderBook))             { Print("APEX: OBISignal init failed");        return INIT_FAILED; }
    if(!g_FootprintSignal.Initialize(&g_WindowManager))   { Print("APEX: FootprintSignal init failed");  return INIT_FAILED; }
    if(!g_AbsorptionSignal.Initialize(&g_WindowManager))  { Print("APEX: AbsorptionSignal init failed"); return INIT_FAILED; }
    if(!g_HVPSignal.Initialize(&g_WindowManager))         { Print("APEX: HVPSignal init failed");        return INIT_FAILED; }
    if(!g_TapeSpeedSignal.Initialize(&g_TickCollector))   { Print("APEX: TapeSpeedSignal init failed");  return INIT_FAILED; }
    if(!g_VPOCSignal.Initialize(&g_WindowManager))        { Print("APEX: VPOCSignal init failed");       return INIT_FAILED; }
    if(!g_SpreadSignal.Initialize(&g_OrderBook))          { Print("APEX: SpreadSignal init failed");     return INIT_FAILED; }

    //--- Session 7: initialize engine layer
    if(!g_DecayManager.Initialize())
        { Print("APEX: DecayManager init failed"); return INIT_FAILED; }
    if(!g_ScoringEngine.Initialize(&g_DecayManager, &g_ConflictFilter))
        { Print("APEX: ScoringEngine init failed"); return INIT_FAILED; }
    if(!g_Regime.Initialize())
        { Print("APEX: RegimeClassifier init failed"); return INIT_FAILED; }
    if(!g_Gate.Initialize())
        { Print("APEX: ConfirmationGate init failed"); return INIT_FAILED; }
    // ConflictFilter has no Initialize() — stateless, uses global state

    //--- Session 8: initialize execution layer
    if(!g_SLEngine.Initialize(&g_WindowManager))
        { Print("APEX: StopLossEngine init failed"); return INIT_FAILED; }
    if(!g_TPEngine.Initialize(&g_WindowManager, &g_VPOCSignal))
        { Print("APEX: TakeProfitEngine init failed"); return INIT_FAILED; }
    if(!g_TradeManager.Initialize())
        { Print("APEX: TradeManager init failed"); return INIT_FAILED; }
    if(!g_PositionTracker.Initialize(&g_TradeManager, &g_TPEngine))
        { Print("APEX: PositionTracker init failed"); return INIT_FAILED; }
    g_TradeManager.SetTracker(&g_PositionTracker);

    //--- Session 9: initialize risk layer
    if(!g_SessionFilter.Initialize())
        { Print("APEX: SessionFilter init failed"); return INIT_FAILED; }
    if(!g_SpreadFilter.Initialize())
        { Print("APEX: SpreadFilter init failed"); return INIT_FAILED; }
    if(!g_NewsFilter.Initialize())
        { Print("APEX: NewsFilter init failed"); return INIT_FAILED; }
    if(!g_RiskManager.Initialize())
        { Print("APEX: RiskManager init failed"); return INIT_FAILED; }

    //--- Inject risk modules into confirmation gate
    g_Gate.SetSessionFilter(&g_SessionFilter);
    g_Gate.SetSpreadFilter(&g_SpreadFilter);
    g_Gate.SetNewsFilter(&g_NewsFilter);
    g_Gate.SetRiskManager(&g_RiskManager);

    //--- Session 10: initialize dashboard
    if(!g_Dashboard.Initialize())
    {
        Print("APEX: DashboardPanel initialization failed");
        return INIT_FAILED;
    }

    //--- Session 11: initialize renderers
    if(!g_FPRenderer.Initialize())
        { Print("APEX: FootprintRenderer init failed"); return INIT_FAILED; }
    if(!g_HVPRenderer.Initialize())
        { Print("APEX: HVPRenderer init failed"); return INIT_FAILED; }
    if(!g_OBRenderer.Initialize())
        { Print("APEX: OBRenderer init failed"); return INIT_FAILED; }
    g_FPRenderer.SetWindowManager(&g_WindowManager);
    g_HVPRenderer.SetWindowManager(&g_WindowManager);
    g_OBRenderer.SetOrderBook(&g_OrderBook);

    //--- Session 12: initialize logging
    if(!g_SessionLogger.Initialize())
        { Print("APEX: SessionLogger init failed"); return INIT_FAILED; }
    if(!g_TradeLogger.Initialize())
        { Print("APEX: TradeLogger init failed"); return INIT_FAILED; }
    if(!g_SignalLogger.Initialize())
        { Print("APEX: SignalLogger init failed"); return INIT_FAILED; }
    g_TradeLogger.SetSessionLogger(&g_SessionLogger);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release order book subscription
    MarketBookRelease(Symbol());

    //--- Session 12: log session summary and close signal log
    g_SessionLogger.WriteSessionSummary();
    g_SignalLogger.Deinitialize();

    //--- Session 11: clean up renderers
    g_FPRenderer.Deinitialize();
    g_HVPRenderer.Deinitialize();
    g_OBRenderer.Deinitialize();

    //--- Session 10: clean up dashboard
    g_Dashboard.Deinitialize();

    //--- Reset event bus
    g_EventBus.Reset();

    PrintFormat("APEX_SCALPER deinitialized. Reason: %d", reason);
}

//+------------------------------------------------------------------+
//| Expert tick handler                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Step 1: Feed tick to data layer (Session 3) ✓
    g_TickCollector.OnTick();
    if(g_TickCollector.IsReady())
        g_CandleBuilder.OnTick(g_TickCollector.GetLatest());
    if(g_TickCollector.IsReady())
        g_FootprintBuilder.OnTick(g_TickCollector.GetLatest());  // Session 4 ✓

    //--- Step 1b: OB snapshot (throttled by InpOBISnapshotInterval ms) (Session 4) ✓
    if(g_OrderBook.IsSnapshotDue())
        g_OrderBook.TakeSnapshot();

    //--- Step 2: Detect new bar and advance window (Session 5) ✓
    bool new_bar = (iTime(Symbol(), InpTimeframe, 0) != g_LastBarTime);
    if(new_bar) g_LastBarTime = iTime(Symbol(), InpTimeframe, 0);
    g_WindowManager.OnTick();  // internally detects bar change, calls Advance(), publishes EVENT_NEW_BAR
    if(new_bar) g_HVPRenderer.OnBarClose();  // Session 11: refresh HVP lines on bar close

    //--- Step 3: OB snapshot throttle is handled inside Step 1b above ✓

    //--- Step 3b: Per-tick signal state updates (Session 6) ✓
    g_VPINSignal.OnTick();
    g_TapeSpeedSignal.OnTick();

    //--- Step 3c: Risk state updates (Session 9) ✓
    g_SessionFilter.OnTick();
    g_SpreadFilter.OnTick();
    g_NewsFilter.OnTick();
    g_RiskManager.OnTick();

    //--- Step 4: Calculate all signals (Session 6) ✓
    SignalResult sig_results[APEX_MAX_SIGNAL_COUNT];
    int sig_count = 0;
    sig_results[sig_count++] = g_DeltaSignal.Calculate();
    sig_results[sig_count++] = g_VPINSignal.Calculate();
    sig_results[sig_count++] = g_OBISignal.CalculateShallow();
    sig_results[sig_count++] = g_OBISignal.CalculateDeep();
    sig_results[sig_count++] = g_FootprintSignal.Calculate();
    sig_results[sig_count++] = g_AbsorptionSignal.Calculate();
    sig_results[sig_count++] = g_HVPSignal.Calculate();
    sig_results[sig_count++] = g_TapeSpeedSignal.Calculate();
    // Supporting signals (informational — not passed to ScoringEngine's core 8)
    g_VPOCSignal.Calculate();    // updates anchor flag for TP engine
    g_SpreadSignal.Calculate();  // updates widening alert for risk/filter

    //--- Step 4b: Regime update (Session 7) ✓
    g_Regime.OnTick();

    //--- Step 5: Composite scoring (Session 7) ✓
    g_LastComposite = g_ScoringEngine.Calculate(sig_results, sig_count);

    //--- Step 6: Trade execution gate + execution (Sessions 7-8) ✓
    int trade_direction = 0;
    if(!g_KillSwitch && g_Gate.ShouldTrade(trade_direction))
    {
        double entry = (trade_direction == 1)
                       ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                       : SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double sl = g_SLEngine.Calculate(trade_direction, entry);
        if(sl > 0.0)
        {
            double tp       = g_TPEngine.Calculate(trade_direction, entry, sl);
            double sl_pts   = MathAbs(entry - sl) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            double lot      = InpUseDynamicSizing
                              ? g_RiskManager.CalculateLotSize(sl_pts)
                              : InpLotSize;
            g_TradeManager.OpenPosition(trade_direction, lot, sl, tp, g_LastComposite);
        }
    }

    //--- Step 7: Position management (Session 8) ✓
    g_PositionTracker.OnTick();

    //--- Step 8: Risk state update — moved to Step 3c above (Session 9) ✓

    //--- Step 9: Publish tick event to bus
    g_EventBus.Publish(EVENT_NEW_TICK);

    //--- Step 10: Redraw dashboard (Session 10) ✓
    g_Dashboard.Redraw();

    //--- Step 11: Update chart renderers (Session 11) ✓
    g_FPRenderer.OnTick();
    g_OBRenderer.OnTick();

    //--- Step 12: Logging (Session 12) ✓
    g_SessionLogger.OnTick();
    g_TradeLogger.OnTick();
    g_SignalLogger.OnTick();
}

//+------------------------------------------------------------------+
//| Order book event handler                                         |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
    //--- Only process for our symbol
    if(symbol != Symbol()) return;

    //--- Session 4: take snapshot on book change event ✓
    g_OrderBook.TakeSnapshot();
}

//+------------------------------------------------------------------+
//| Chart event handler (panel interaction)                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    //--- Session 10: delegate to dashboard ✓
    g_Dashboard.OnChartEvent(id, lparam, dparam, sparam);
}
