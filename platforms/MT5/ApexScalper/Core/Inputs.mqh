//+------------------------------------------------------------------+
//| Inputs.mqh — APEX_SCALPER                                        |
//| All input and sinput parameter declarations.                     |
//| No magic numbers elsewhere — always reference these.            |
//+------------------------------------------------------------------+


//--- Window
input int             InpWindowSize            = 20;           // Sliding window size (candles)
input ENUM_TIMEFRAMES InpTimeframe             = PERIOD_M1;    // Primary timeframe

//--- Signal Weights (must sum to 1.0 — enforced in OnInit)
input double  InpWeightDelta          = 0.20;    // Weight: Cumulative Delta signal
input double  InpWeightVPIN           = 0.20;    // Weight: VPIN signal
input double  InpWeightOBI            = 0.15;    // Weight: OBI shallow signal
input double  InpWeightOBIDeep        = 0.10;    // Weight: OBI deep signal
input double  InpWeightFootprint      = 0.15;    // Weight: Footprint stacked imbalance
input double  InpWeightHVP            = 0.05;    // Weight: HVP regression slope
input double  InpWeightAbsorption     = 0.10;    // Weight: Absorption signal
input double  InpWeightTapeSpeed      = 0.05;    // Weight: Tape speed signal

//--- Composite Scoring
input double  InpCompositeThreshold   = 1.80;    // Minimum |composite score| to trade
input int     InpMinSignalsAgree      = 4;        // Min signals in same direction
input bool    InpEnableConflictFilter = true;     // Enable conflict filter
input double  InpConflictScoreBand    = 0.30;     // Skip if score near threshold + conflict

//--- Delta Signal
input double  InpDeltaZScoreThreshold  = 2.0;    // Z-score of delta to score 3.0
input int     InpDeltaAccelPeriod      = 3;       // Candles for delta acceleration
input double  InpDeltaEfficiencyMin    = 0.15;    // Min delta/volume ratio to count
input bool    InpEnableDeltaDivergence = true;    // Enable delta divergence sub-signal

//--- VPIN Signal
input int     InpVPINBucketVolume     = 5000;     // Volume per VPIN bucket
input int     InpVPINLookbackBuckets  = 10;       // Number of buckets to evaluate
input double  InpVPINThreshold        = 0.70;     // VPIN > this = toxic flow

//--- Order Book Imbalance
input int     InpOBILevelsShallow     = 3;        // Levels for shallow OBI
input int     InpOBILevelsDeep        = 10;       // Levels for deep OBI
input double  InpOBIWeightDecay       = 0.5;      // Exponential weight decay per level
input int     InpOBISnapshotInterval  = 500;      // Milliseconds between OB snapshots
input int     InpOBIMomentumPeriod    = 5;        // Snapshots for OBI momentum
input double  InpOBISpoofDetectSnap   = 3;        // Snapshots for spoof detection
input double  InpOBISpoofThreshold    = 0.40;     // Max OBI variance to call spoof

//--- Footprint / Stacked Imbalance
input int     InpMinStackedRows       = 3;        // Min consecutive imbalance rows to count
input double  InpImbalanceRatio       = 3.0;      // ask_vol / bid_vol > this = imbalance
input int     InpFootprintTickSize    = 1;        // Price levels in ticks for footprint rows

//--- Absorption
input double  InpAbsorptionMinVolume  = 10000;    // Min volume to qualify for absorption check
input double  InpAbsorptionRangeMax   = 3.0;      // Max price range in points for high absorption
input int     InpAbsorptionLookback   = 5;        // Candles back to check for absorption zones

//--- HVP Signal
input double  InpHVPStdDevMultiplier  = 1.5;      // Std devs above mean volume to qualify as HVP
input int     InpHVPMinNodes          = 3;        // Min HVP nodes for regression
input double  InpHVPSlopeThreshold    = 0.5;      // Min absolute slope to score

//--- Tape Speed
input int     InpTapeSpeedWindow      = 10;       // Seconds for trades/sec calculation
input double  InpTapeSpeedZScore      = 2.0;      // Z-score threshold for spike detection
input double  InpTapeSpeedDirectional = 0.65;     // Min directional fraction to count

//--- VPOC Migration
input int     InpVPOCLookback         = 5;        // Candles for VPOC migration analysis
input double  InpVPOCMigrationTicks   = 3.0;      // Min VPOC shift in ticks to count as migration

//--- Spread Dynamics
input double  InpSpreadWideningFactor = 2.0;      // Current/rolling spread > this = widening alert
input int     InpSpreadRollingPeriod  = 20;       // Snapshots for rolling spread average

//--- Signal TTL (milliseconds)
input int     InpTTL_Delta            = 5000;     // Delta signal time-to-live (ms)
input int     InpTTL_VPIN             = 8000;     // VPIN signal TTL (ms)
input int     InpTTL_OBI              = 2000;     // OBI signal TTL (ms)
input int     InpTTL_Footprint        = 10000;    // Footprint signal TTL (ms)
input int     InpTTL_Absorption       = 15000;    // Absorption signal TTL (ms)
input int     InpTTL_HVP              = 20000;    // HVP signal TTL (ms)
input int     InpTTL_TapeSpeed        = 3000;     // Tape speed signal TTL (ms)
input int     InpTTL_VPOC             = 30000;    // VPOC signal TTL (ms)

//--- Regime Classifier
input ENUM_TIMEFRAMES InpRegimeTF     = PERIOD_M5; // Higher TF for regime detection
input int     InpADXPeriod            = 14;        // ADX period
input double  InpADXTrendingThreshold = 25.0;      // ADX > this = trending
input double  InpADXRangingThreshold  = 18.0;      // ADX < this = ranging
input double  InpBBWidthExpanding     = 0.002;     // BB width ratio threshold: expanding
input double  InpBBWidthContracting   = 0.0008;    // BB width ratio threshold: contracting
input int     InpVPOCStabilityBars    = 3;         // Bars to assess VPOC stability

//--- Execution
input double  InpLotSize              = 0.01;      // Fixed lot size (if dynamic sizing off)
input bool    InpUseDynamicSizing     = true;      // Use dynamic lot sizing
input double  InpRiskPercent          = 0.5;       // Risk % per trade of account balance
input int     InpSlippage             = 3;         // Max slippage in points
input int     InpMagicNumber          = 20240101;  // EA magic number
input string  InpComment              = "APEX_v1"; // Order comment

//--- Stop Loss
input bool    InpSLBehindHVP          = true;      // Place SL behind nearest HVP
input double  InpSLFixedPoints        = 15.0;      // Fallback fixed SL in points
input double  InpSLBufferPoints       = 2.0;       // Extra buffer beyond HVP for SL
input bool    InpSLBehindImbalance    = true;      // Alt SL behind stacked imbalance

//--- Take Profit
input bool    InpTPDynamic            = true;      // Use dynamic TP placement
input double  InpTPFixedRR            = 1.5;       // Fixed R:R if dynamic off
input bool    InpTPAtOppositeHVP      = true;      // TP at next opposing HVP
input bool    InpTPTrailingAfterHVP   = true;      // Trail after first HVP hit
input double  InpTrailingStep         = 3.0;       // Trailing stop step in points

//--- Risk
input double  InpMaxDailyLossPercent  = 2.0;       // Stop trading after X% daily loss
input int     InpMaxOpenPositions     = 2;         // Max concurrent open positions
input double  InpMaxDrawdownPercent   = 5.0;       // Drawdown circuit breaker %
input int     InpMinBarsBetweenTrades = 2;         // Cooldown bars after trade closes

//--- Session Filter
input bool    InpTradeAsian           = false;     // Allow trading: Asian session
input bool    InpTradeLondon          = true;      // Allow trading: London session
input bool    InpTradeNewYork         = true;      // Allow trading: New York session
input bool    InpTradeLondonNY        = true;      // Allow trading: London/NY overlap
input string  InpAsianStart           = "00:00";   // Asian session start (server time)
input string  InpAsianEnd             = "09:00";   // Asian session end
input string  InpLondonStart          = "08:00";   // London session start
input string  InpLondonEnd            = "17:00";   // London session end
input string  InpNewYorkStart         = "13:00";   // New York session start
input string  InpNewYorkEnd           = "22:00";   // New York session end

//--- Spread Filter
input double  InpMaxSpreadPoints      = 30.0;      // Do not trade above this spread

//--- News Filter
input bool    InpEnableNewsFilter     = true;      // Enable news blackout filter
input int     InpNewsMinutesBefore    = 5;         // Minutes before news to block
input int     InpNewsMinutesAfter     = 5;         // Minutes after news to block

//--- UI
input bool    InpShowDashboard        = true;      // Show dashboard panel
input bool    InpShowFootprint        = true;      // Show footprint overlay
input bool    InpShowHVPLines         = true;      // Show HVP horizontal lines
input bool    InpShowOBDepth          = true;      // Show order book depth viz
input int     InpPanelX               = 20;        // Panel X position
input int     InpPanelY               = 30;        // Panel Y position
input int     InpPanelWidth           = 280;       // Panel width in pixels
input color   InpPanelBG              = C'15,15,20';   // Panel background color
input color   InpPanelBorder          = C'40,40,60';   // Panel border color
input color   InpBullColor            = C'0,200,100';  // Bullish color
input color   InpBearColor            = C'220,60,60';  // Bearish color
input color   InpNeutralColor         = C'120,120,140'; // Neutral color
input color   InpHighlightColor       = C'255,200,0';  // Highlight / warning color

//--- Logging
input bool    InpEnableTradeLog       = true;      // Log every trade to CSV
input bool    InpEnableSignalLog      = false;     // Log signals per tick (high I/O)
input bool    InpEnableSessionLog     = true;      // Log session summary on stop
input string  InpLogFolder            = "ApexScalper\\Logs\\"; // Log output folder
