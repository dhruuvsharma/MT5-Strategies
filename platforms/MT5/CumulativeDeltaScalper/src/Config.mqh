//+------------------------------------------------------------------+
//| Config.mqh — All inputs and constants for CumulativeDeltaScalper |
//| v2.0 — Sniper sessions / risk-based sizing / fast exits           |
//+------------------------------------------------------------------+
#ifndef CONFIG_MQH
#define CONFIG_MQH

//=== Session enums ================================================
enum ENUM_SESSION_ID
{
   SESSION_NONE    = 0,
   SESSION_ASIA    = 1,
   SESSION_LONDON  = 2,
   SESSION_NY      = 3,
   SESSION_OVERLAP = 4
};

//=== Delta Settings ===============================================
input group "Delta Settings"
input int    WindowSize       = 10;     // Number of candles in sliding window
input int    DeltaThreshold   = 300;    // Cumulative delta trigger level

//=== Sessions (GMT) ===============================================
input group "Sessions (GMT)"
input bool   UseSessionFilter   = true;
input bool   OverlapOnly        = true;     // Only trade London/NY overlap (highest liquidity)
input int    OverlapStartHour   = 12;
input int    OverlapStartMin    = 30;
input int    OverlapEndHour     = 16;
input int    OverlapEndMin      = 0;

input bool   UseAsiaSession     = false;
input int    AsiaStartHour      = 0;
input int    AsiaStartMin       = 0;
input int    AsiaEndHour        = 7;
input int    AsiaEndMin         = 0;

input bool   UseLondonSession   = true;
input int    LondonStartHour    = 7;
input int    LondonStartMin     = 0;
input int    LondonEndHour      = 12;
input int    LondonEndMin       = 0;

input bool   UseNewYorkSession  = true;
input int    NYStartHour        = 12;
input int    NYStartMin         = 30;
input int    NYEndHour          = 17;
input int    NYEndMin           = 0;

//=== Sniper Filters ===============================================
input group "Sniper Filters (confirmation stack)"
input int    MinConfirmations    = 5;     // Of 5 supporting confirmations (crossover always required)
input int    EMASlopeBars        = 3;     // Bars to measure HTF EMA slope over
input double ADXThreshold        = 18.0;  // M15 ADX(14) min for trending regime
input double SpreadAvgMultiplier = 1.5;   // Skip if spread > rolling avg × this
input int    SpreadHistorySize   = 30;    // Rolling window of spread samples

//=== Trade Settings ===============================================
input group "Trade Settings"
input bool   UseRiskBasedSizing  = true;
input double RiskPercentPerTrade = 1.0;   // % of balance risked at SL (raise for "big position")
input double FixedLotSize        = 0.01;  // Used only if UseRiskBasedSizing = false
input double MaxLotSize          = 5.0;   // Hard safety cap
input double TP_Multiplier       = 0.4;   // TP = ATR × this (sniper: tight, easy to hit)
input double SL_Multiplier       = 0.8;   // SL = ATR × this
input bool   UseBreakeven        = false; // Auto-move SL to entry on N pips profit
input double BreakevenPips       = 1.5;
input int    MaxSpreadPoints     = 15;    // Hard ceiling regardless of rolling avg
input int    Slippage            = 3;

//=== Fast Exit ====================================================
input group "Fast Exit"
input int    MaxTradeSeconds      = 90;   // Time-out: close at market if neither TP/SL hit
input bool   AdverseDeltaExit     = true; // Close when cumDelta crosses against position
input int    AdverseDeltaCooldown = 5;    // Seconds after entry before adverse-exit can trigger

//=== Filters ======================================================
input group "Filters"
input bool   UseHTFFilter     = true;     // M15 EMA(50) bid-vs-EMA filter
input double MinATR           = 0.00030;  // Skip if too flat
input double MaxATR           = 0.00200;  // Skip if too volatile

//=== Risk Management ==============================================
input group "Risk Management"
input int    MaxTradesPerSession    = 2;     // Hard cap per session
input int    MaxDailyTrades         = 3;     // Hard cap across the day
input double MaxDailyLossPercent    = 2.0;   // % of day-start balance
input int    MinSecondsBetweenTrades= 900;   // 15 min hard floor (any → any)
input int    LossCooldownMinutes    = 15;    // Extra cooldown after a loss
input bool   StopAfterFirstWin      = true;  // Halt session after a win (sniper discipline)
input bool   StopAfterFirstLoss     = true;  // Halt session after a loss (no revenge trades)

//=== Display ======================================================
input group "Display"
input bool   ShowUI             = true;
input double FootprintBlockPips = 1.0;

//=== EA Identity ==================================================
input group "EA Identity"
input int    MagicNumber  = 20250411;
input string EAComment    = "CDScalper";

//=== Constants ====================================================
#define EA_NAME       "CumulativeDeltaScalper"
#define EA_PREFIX     "[CDScalper] "
#define DASHBOARD_X   20
#define DASHBOARD_Y   30
#define DASHBOARD_FONT_SIZE   10
#define DASHBOARD_FONT        "Consolas"
#define DASHBOARD_LINE_HEIGHT 18
#define BE_BUFFER_PIPS 0.5
#define STOPS_LEVEL_BUFFER_MULT 1.1   // Multiply broker stops-level by this for safety

//--- Sliding Window UI Constants
#define SW_RECT_NAME          "CDScalper_SlidingWindow_Rect"
#define SW_DELTA_PREFIX       "CDScalper_Delta_"
#define SW_LIVE_DELTA_NAME    "CDScalper_LiveDelta"
#define SW_CUMDELTA_NAME      "CDScalper_CumDelta_Label"
#define SW_TEXT_SIZE          8
#define SW_RECT_WIDTH         2
#define SW_RECT_STYLE         STYLE_DOT
#define SW_FP_BG_PREFIX       "CDScalper_FpBg_"
#define SW_FP_TX_PREFIX       "CDScalper_FpTx_"
#define SW_FP_MAX_LEVELS      40

//--- Indicator periods
#define ATR_PERIOD     14
#define EMA_PERIOD     50
#define EMA_TIMEFRAME  PERIOD_M15
#define ADX_PERIOD     14
#define ADX_TIMEFRAME  PERIOD_M15

//=== Global State =================================================
int      g_atrHandle     = INVALID_HANDLE;
int      g_emaHandle     = INVALID_HANDLE;
int      g_adxHandle     = INVALID_HANDLE;
double   g_prevBid       = 0.0;
int      g_uptickCount   = 0;
int      g_downtickCount = 0;
int      g_deltaBuffer[];
int      g_bufferIndex   = 0;
int      g_bufferFilled  = 0;
datetime g_lastBarTime   = 0;
int      g_prevCumDelta  = 0;
int      g_liveDelta     = 0;

//--- Pip size (computed in MarketInit; broker-aware)
double   g_pipSize       = 0.0001;

//--- Daily Tracking
int      g_dailyTradeCount = 0;
double   g_dailyPnL        = 0.0;
double   g_dayStartBalance = 0.0;
datetime g_lastTradeDay    = 0;

//--- Cooldowns / per-trade timing
datetime g_lastLossTime    = 0;
datetime g_lastTradeTime   = 0;       // Any entry, win or loss

//--- Session tracking
ENUM_SESSION_ID g_currentSession = SESSION_NONE;
int      g_sessionTradeCount     = 0;
int      g_sessionWins           = 0;
int      g_sessionLosses         = 0;

//--- Spread history (rolling avg, sampled per bar)
int      g_spreadHistory[];
int      g_spreadHistoryIdx      = 0;
int      g_spreadHistoryFilled   = 0;

//--- Open-trade tracking (for fast exits)
datetime g_openTradeTime         = 0;
int      g_openTradeDirection    = 0;  // +1 buy, -1 sell, 0 none

//--- Breakeven
bool     g_breakevenApplied = false;

//--- Last seen exit ticket (for OnTradeTransaction dedup if needed)
ulong    g_lastSeenExitTicket = 0;

//--- Dashboard object names
string   g_dashLabels[];

#endif
