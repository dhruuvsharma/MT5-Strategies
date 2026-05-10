//+------------------------------------------------------------------+
//|                                                      Config.mqh |
//|                                        DeltaFadeEA — Dhruv Sharma |
//+------------------------------------------------------------------+
#ifndef CONFIG_MQH
#define CONFIG_MQH

//--- EA Identity
#define EA_NAME        "DeltaFadeEA"
#define EA_VERSION     "3.00"

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+

//--- Core
input int    MagicNumber   = 12345;  // Magic number
input bool   EnableTrading = true;   // Enable automated trading

//--- Sliding Window
input int    WindowSize          = 20;   // Candles in trading window
input int    AnalysisWindowSize  = 50;   // Candles in threshold analysis window

//--- Trend Filter
input int    TrendEMAPeriod = 50;    // EMA period for trend direction (0 = disabled)
input bool   TrendFollowing = true;  // true = trade WITH trend pullbacks, false = fade (contrarian)

//--- Signal Tuning
input double ThresholdMultiplier       = 2.0;   // MAD multiplier for dynamic thresholds
input bool   RequireBothDeltas         = true;   // Require BOTH tick+vol deltas
input bool   RequireSlopeConfirmation  = true;   // Require VWP slope confirmation

//--- Trade Management
input int    MaxTradesPerDay       = 5;     // Max trades per day (0 = unlimited)
input int    MinBarsBetweenTrades  = 10;    // Cooldown bars between trades

//--- Risk Management
input double LotSize           = 0.01;  // Fixed lot size (0 = risk-based)
input double RiskPercent       = 2.0;   // Risk % per trade (when LotSize = 0)
input int    StopLossPoints    = 500;   // SL in points ($5 on XAUUSD)
input int    TakeProfitPoints  = 0;     // TP in points (0 = use RR ratio)
input double RiskRewardRatio   = 0.6;   // R:R ratio — TP = 300pts ($3) for high WR
input int    MaxSpread         = 30;    // Max spread in points
input int    Slippage          = 10;    // Max slippage in points
input int    TrailingStart     = 200;   // Trailing stop distance in points

//--- Session Filter
input bool   EnableTimeFilter = true;  // Enable session time filter
input int    StartHour        = 8;     // Session start hour (London open)
input int    EndHour          = 17;    // Session end hour (NY close)

//+------------------------------------------------------------------+
//| HARDCODED CONSTANTS                                              |
//+------------------------------------------------------------------+

//--- Visual defaults (only used in live / visual-tester)
#define TEXT_SIZE               8
#define TICK_WINDOW_COLOR       clrBlue
#define VOLUME_WINDOW_COLOR     clrSkyBlue
#define THRESHOLD_WINDOW_WIDTH  1
#define UP_TREND_COLOR          clrLime
#define DOWN_TREND_COLOR        clrRed
#define FOOTPRINT_LINE_WIDTH    2

//--- Volume Weighted Price weights
#define VWP_CLOSE_WEIGHT    0.4
#define VWP_TYPICAL_WEIGHT  0.4
#define VWP_OPEN_WEIGHT     0.2

//--- Threshold bounds (fraction of base threshold)
#define THRESHOLD_MIN_MULT  0.3
#define THRESHOLD_MAX_MULT  3.0
#define MIN_ABSOLUTE_THRESHOLD 80.0

//--- Statistical
#define MIN_MAD_VALUE       10.0
#define MAD_SCALE_FACTOR    1.4826

#endif
