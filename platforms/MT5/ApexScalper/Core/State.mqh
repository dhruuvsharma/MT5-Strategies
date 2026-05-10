//+------------------------------------------------------------------+
//| State.mqh — APEX_SCALPER                                         |
//| Global state variables. No logic. Populated by modules.         |
//| All cross-module shared state lives here — nowhere else.        |
//+------------------------------------------------------------------+

#include "Defines.mqh"

//--- Regime state (populated by RegimeClassifier)
ApexRegime      g_CurrentRegime      = REGIME_UNDEFINED;
string          g_RegimeString       = "UNDEFINED";

//--- Composite score state (populated by ScoringEngine)
CompositeResult g_LastComposite;
bool            g_KillSwitch         = false;      // true = no new trades for rest of day

//--- Session tracking
TradingSession  g_CurrentSession     = SESSION_OFF;
int             g_BarsProcessed      = 0;          // Total bars seen since EA start
int             g_BarsSinceLastTrade = 999;        // Bars elapsed since last trade closed
datetime        g_SessionStartTime;                // Time OnInit completed

//--- Performance tracking (reset at midnight by RiskManager)
double          g_DailyPnL           = 0.0;        // Realized P&L today
double          g_PeakEquity         = 0.0;        // Highest equity since session start
int             g_TotalTrades        = 0;          // Trades opened this session
int             g_WinningTrades      = 0;          // Winning trades this session

//--- Bar change detection (used by OnTick for per-bar logic outside WindowManager)
datetime        g_LastBarTime        = 0;

//--- Order book timing (used to throttle snapshot frequency)
datetime        g_LastOBSnapshotTime = 0;
int             g_LastOBSnapshotMs   = 0;

//--- Spread state (populated by SpreadFilter / SpreadSignal)
double          g_CurrentSpread      = 0.0;
bool            g_SpreadAlert        = false;      // true = spread widening without direction

//--- News filter state (populated by NewsFilter)
bool            g_NewsBlackout       = false;      // true = within news window, no trading
