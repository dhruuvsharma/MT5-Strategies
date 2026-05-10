//+------------------------------------------------------------------+
//| Config.mqh — FootprintChartPro                                    |
//| All inputs, enums, structs, constants, and global state           |
//+------------------------------------------------------------------+
#ifndef CONFIG_MQH
#define CONFIG_MQH

//+------------------------------------------------------------------+
//| EA Identity                                                       |
//+------------------------------------------------------------------+
#define EA_NAME          "FootprintChartPro"
#define EA_PREFIX        "FPPro_"
#define EA_VERSION       "1.0"

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_VP_MODE
{
   VP_MODE_SESSION_TIME = 0,   // Session Time
   VP_MODE_BAR_COUNT    = 1,   // Bar Count
   VP_MODE_FULL_DAY     = 2    // Full Day
};

enum ENUM_VP_DISPLAY
{
   VP_DISPLAY_TOTAL = 0,   // Total Volume
   VP_DISPLAY_DELTA = 1,   // Delta
   VP_DISPLAY_BUY   = 2,   // Buy Volume
   VP_DISPLAY_SELL  = 3    // Sell Volume
};

enum ENUM_COLOR_THEME
{
   THEME_CLASSIC_GREEN_RED  = 0,
   THEME_BLUE_ORANGE        = 1,
   THEME_CYAN_MAGENTA       = 2,
   THEME_LIME_PINK          = 3,
   THEME_GOLD_PURPLE        = 4,
   THEME_TEAL_CORAL         = 5,
   THEME_SKY_CRIMSON        = 6,
   THEME_MINT_ROSE          = 7,
   THEME_ORANGE_DARK_GREY   = 8,
   THEME_GREEN_DARK_GREY    = 9,
   THEME_NAVY_SLATE         = 10,
   THEME_NAVY_GOLD          = 11,
   THEME_WHITE_DARK_GREY    = 12,
   THEME_EMERALD_WHITE      = 13,
   THEME_CHERRY_TEAL        = 14,
   THEME_OLIVE_SANDY        = 15
};

//+------------------------------------------------------------------+
//| Data Structures                                                   |
//+------------------------------------------------------------------+
struct PriceLevel
{
   double price;
   long   bidVolume;
   long   askVolume;
   long   buyVolume;
   long   sellVolume;
   long   delta;
   int    imbalanceLevel;   // 0=none, 1=tier1, 2=tier2, 3=tier3
   bool   isBuyImbalance;
};

struct FootprintBar
{
   datetime   time;
   double     open, high, low, close;
   PriceLevel levels[];
   int        levelCount;
   long       totalVolume;
   long       totalDelta;
   long       cumulativeDelta;
   double     poc;
   int        pocIndex;
   bool       isHistorical;
};

struct DOMLevel
{
   double price;
   long   bidOrders;
   long   askOrders;
   long   buyExecuted;
   long   sellExecuted;
   long   netDelta;
   bool   flashBuy;
   bool   flashSell;
};

struct TSTick
{
   datetime time;
   double   price;
   long     volume;
   int      direction;   // 1=buy, -1=sell, 0=neutral
   bool     isBigOrder;
};

struct VolumeProfileLevel
{
   double price;
   long   totalVolume;
   long   buyVolume;
   long   sellVolume;
   long   delta;
};

struct SupplyDemandZone
{
   double   topPrice;
   double   bottomPrice;
   bool     isSupply;
   datetime createdTime;
   bool     isActive;
};

struct EconomicEvent
{
   datetime eventTime;
   string   eventTitle;
   string   currency;
   string   country;
   int      importance;   // 1=Low, 2=Medium, 3=High
};

struct MiniChartCandle
{
   datetime time;
   double   open, high, low, close;
};

struct AnalystSection
{
   string title;
   string content;
   color  textColor;
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- Main Panel
input group "Main Panel"
input int    Input_MainPanelX      = 50;       // Panel X position
input int    Input_MainPanelY      = 50;       // Panel Y position
input int    Input_MainPanelWidth  = 1200;     // Panel width
input int    Input_MainPanelHeight = 800;      // Panel height

//--- Footprint Settings
input group "Footprint Settings"
input int    Input_BucketPoints    = 40;       // Price bucket size in points
input int    Input_BarWidth        = 80;       // Footprint bar width (px)
input int    Input_BarSpacing      = 10;       // Spacing between bars (px)
input int    Input_CellHeight      = 25;       // Cell height (px)
input int    Input_CellGap         = 2;        // Gap between cells (px)
input int    Input_CellPadding     = 5;        // Text padding inside cells
input int    Input_VisibleBars     = 12;       // Number of visible footprint bars

//--- Volume Inference
input group "Volume Inference"
input bool   Input_EnableVolumeInference = true;   // Enable tick volume inference
input long   Input_BaseInferredVolume    = 100;    // Base inferred volume per tick
input double Input_VolumeScaleFactor     = 0.5;    // Volume scale factor
input long   Input_MinInferredVolume     = 10;     // Minimum inferred volume
input long   Input_MaxInferredVolume     = 10000;  // Maximum inferred volume

//--- Imbalance Detection
input group "Imbalance Detection"
input double Input_ImbalanceTier1Ratio     = 2.0;  // Tier 1 ratio threshold
input double Input_ImbalanceTier2Ratio     = 3.0;  // Tier 2 ratio threshold
input double Input_ImbalanceTier3Ratio     = 5.0;  // Tier 3 ratio threshold
input long   Input_MinImbalanceVolume      = 50;   // Minimum volume for imbalance
input int    Input_ImbalanceTier1SizeBoost = 0;    // Tier 1 font size boost
input int    Input_ImbalanceTier2SizeBoost = 2;    // Tier 2 font size boost
input int    Input_ImbalanceTier3SizeBoost = 4;    // Tier 3 font size boost

//--- DOM Panel
input group "DOM Panel"
input int    Input_DOMPanelWidth    = 300;     // DOM panel width
input int    Input_DOMPanelHeight   = 600;     // DOM panel height
input int    Input_DOMVisibleLevels = 12;      // Visible DOM levels
input bool   Input_ShowDOMGridlines = true;    // Show DOM gridlines

//--- Volume Profile
input group "Volume Profile"
input ENUM_VP_MODE    Input_VPMode         = VP_MODE_SESSION_TIME;  // Profile mode
input int             Input_VPBarCount     = 50;                    // Bar count (bar count mode)
input string          Input_VPSessionStart = "08:00";               // Session start (HH:MM)
input ENUM_VP_DISPLAY Input_VPDisplayType  = VP_DISPLAY_TOTAL;      // Display type
input int             Input_VPPanelWidth   = 200;                   // VP panel width
input int             Input_VPPanelHeight  = 600;                   // VP panel height
input double          Input_VPBarWidthScale = 1.0;                  // VP bar width scale

//--- Time & Sales
input group "Time & Sales"
input int    Input_TSPanelWidth    = 300;      // T&S panel width
input int    Input_TSPanelHeight   = 400;      // T&S panel height
input int    Input_TSVisibleRows   = 15;       // Visible rows
input int    Input_MaxTSHistory    = 500;      // Max tick history
input long   Input_BigOrderThreshold = 500;    // Big order volume threshold

//--- Signal Meter
input group "Signal Meter"
input double Input_ATRTrendThreshold     = 1.2;   // ATR trend/range ratio
input int    Input_POCAcceptanceBars     = 3;      // POC acceptance bars
input double Input_POCAcceptanceDistance = 10.0;   // POC acceptance distance (points)

//--- Chart Analyst
input group "Chart Analyst"
input int    Input_AnalystPanelWidth    = 600;     // Analyst panel width
input int    Input_AnalystPanelHeight   = 500;     // Analyst panel height
input int    Input_AnalystRefreshSeconds = 30;     // Analyst refresh interval

//--- Indicators
input group "Indicators"
input int    Input_IndicatorPanelWidth  = 200;     // Indicator panel width
input int    Input_IndicatorPanelHeight = 150;     // Indicator panel height
input int    Input_RSIOverbought        = 70;      // RSI overbought level
input int    Input_RSIOversold          = 30;      // RSI oversold level
input int    Input_MACDFast             = 12;      // MACD fast period
input int    Input_MACDSlow             = 26;      // MACD slow period
input int    Input_MACDSignal           = 9;       // MACD signal period

//--- Supply & Demand Zones
input group "Supply & Demand Zones"
input int    Input_SwingLength           = 5;      // Swing detection length
input int    Input_ZoneLookback          = 100;    // Zone lookback bars
input double Input_VolumeRatioFilter     = 1.2;    // Volume ratio filter
input double Input_ATRZoneWidthMultiplier = 0.5;   // ATR zone width multiplier
input int    Input_MaxZones              = 10;     // Maximum zones
input int    Input_ZoneOpacity           = 128;    // Zone opacity (0-255)

//--- Economic Calendar
input group "Economic Calendar"
input int    Input_CalendarPanelWidth    = 400;    // Calendar panel width
input int    Input_CalendarPanelHeight   = 300;    // Calendar panel height
input int    Input_CalendarMaxRows       = 10;     // Max calendar rows
input int    Input_CalendarRefreshSeconds = 60;    // Calendar refresh interval

//--- Mini Session Chart
input group "Mini Session Chart"
input int    Input_MiniChartWidth    = 250;        // Mini chart width
input int    Input_MiniChartHeight   = 150;        // Mini chart height
input string Input_SessionStartTime = "08:00";     // Session start (HH:MM)
input string Input_SessionEndTime   = "17:00";     // Session end (HH:MM)

//--- Fonts
input group "Fonts"
input string Input_PrimaryFont   = "Segoe UI";    // Primary font
input string Input_MonospaceFont = "Consolas";     // Monospace font
input int    Input_BaseFontSize  = 10;             // Base font size
input int    Input_SmallFontSize = 8;              // Small font size
input int    Input_LargeFontSize = 14;             // Large font size

//--- Theme & Colors
input group "Theme & Colors"
input ENUM_COLOR_THEME Input_Theme            = THEME_CLASSIC_GREEN_RED;  // Color theme
input bool   Input_ThemeOverrideAll           = false;     // Apply theme to all elements
input int    Input_RefreshRateMS              = 100;       // Canvas refresh rate (ms)

//--- Six-Level Intensity Colors
input group "Intensity Colors"
input color  Input_BuyerHighColor             = C'0,170,0';    // Buyer high (>70%)
input color  Input_BuyerMediumColor           = C'0,255,0';    // Buyer medium (40-70%)
input color  Input_BuyerLowColor              = C'136,255,136'; // Buyer low (<40%)
input color  Input_SellerHighColor            = C'170,0,0';    // Seller high (>70%)
input color  Input_SellerMediumColor          = C'255,0,0';    // Seller medium (40-70%)
input color  Input_SellerLowColor             = C'255,136,136'; // Seller low (<40%)
input color  Input_NeutralCellColor           = C'68,68,68';   // Neutral cell
input double Input_HighIntensityThreshold     = 70.0;          // High intensity %
input double Input_MediumIntensityThreshold   = 40.0;          // Medium intensity %

//+------------------------------------------------------------------+
//| Theme-Applied Colors (set by ApplyColorTheme)                     |
//+------------------------------------------------------------------+
color g_BullCandleColor      = C'0,170,0';
color g_BearCandleColor      = C'170,0,0';
color g_BuyTextColor         = C'0,255,0';
color g_SellTextColor        = C'255,0,0';
color g_PanelBackgroundColor = C'30,30,30';
color g_TextColor            = C'204,204,204';
color g_HeaderTextColor      = C'255,255,255';
color g_BullishTextColor     = C'0,200,0';
color g_BearishTextColor     = C'200,0,0';
color g_NeutralTextColor     = C'180,180,180';
color g_POCLineColor         = C'255,215,0';
color g_VAHLineColor         = C'0,150,255';
color g_VALLineColor         = C'0,150,255';
color g_GaugeArcColor        = C'100,100,100';
color g_StrongSellColor      = C'200,0,0';
color g_SellColor            = C'255,80,80';
color g_NeutralGaugeColor    = C'180,180,0';
color g_BuyColor             = C'80,255,80';
color g_StrongBuyColor       = C'0,200,0';
color g_PointerColor         = C'255,255,255';
color g_BigOrderHighlightColor = C'80,80,0';
color g_OverboughtLineColor  = C'255,80,80';
color g_OversoldLineColor    = C'80,255,80';
color g_RSILineColor         = C'0,150,255';
color g_MACDBullColor        = C'0,200,0';
color g_MACDBearColor        = C'200,0,0';
color g_SupplyZoneColor      = C'200,50,50';
color g_DemandZoneColor      = C'50,200,50';
color g_VPTotalVolumeColor   = C'100,100,200';
color g_VPDeltaBuyColor      = C'0,200,0';
color g_VPDeltaSellColor     = C'200,0,0';
color g_VPBuyVolumeColor     = C'0,170,0';
color g_VPSellVolumeColor    = C'170,0,0';

//--- Imbalance colors
color g_ImbalanceTier1BuyColor  = C'0,120,0';
color g_ImbalanceTier1SellColor = C'120,0,0';
color g_ImbalanceTier2BuyColor  = C'0,180,0';
color g_ImbalanceTier2SellColor = C'180,0,0';
color g_ImbalanceTier3BuyColor  = C'0,255,0';
color g_ImbalanceTier3SellColor = C'255,0,0';

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
#define FP_MAX_BARS        600
#define FP_MAX_LEVELS      500
#define FP_MAX_DOM_LEVELS  40
#define FP_MAX_TS_TICKS    500
#define FP_MAX_ZONES       20
#define FP_CANVAS_NAME     "FPPro_Canvas"

//+------------------------------------------------------------------+
//| Global State                                                      |
//+------------------------------------------------------------------+
FootprintBar     g_fpBars[];
int              g_fpBarCount       = 0;
DOMLevel         g_domLevels[];
int              g_domLevelCount    = 0;
TSTick           g_tsTicks[];
int              g_tsTickCount      = 0;
VolumeProfileLevel g_vpLevels[];
int              g_vpLevelCount     = 0;
SupplyDemandZone g_zones[];
int              g_zoneCount        = 0;
EconomicEvent    g_calendarEvents[];
int              g_calendarCount    = 0;
MiniChartCandle  g_sessionCandles[];
int              g_sessionCandleCount = 0;
AnalystSection   g_analystSections[9];

double           g_sessionPOC       = 0.0;
double           g_sessionVAH       = 0.0;
double           g_sessionVAL       = 0.0;
datetime         g_lastAnalystUpdate = 0;
datetime         g_lastCalendarUpdate = 0;
datetime         g_lastBarTime      = 0;
long             g_prevCumDelta     = 0;
double           g_prevBid          = 0.0;

//--- Panel redraw flags
bool             g_domNeedsRedraw         = true;
bool             g_footprintNeedsRedraw   = true;
bool             g_volumeProfileNeedsRedraw = true;

//--- Time & Sales bar totals
long             g_tsBarBuyVolume   = 0;
long             g_tsBarSellVolume  = 0;

//--- Indicator handles
int              g_hRSI             = INVALID_HANDLE;
int              g_hMACD            = INVALID_HANDLE;
int              g_hATR             = INVALID_HANDLE;
int              g_hMA9             = INVALID_HANDLE;
int              g_hMA21            = INVALID_HANDLE;
int              g_hMA50            = INVALID_HANDLE;
int              g_hATRSlow         = INVALID_HANDLE;
int              g_hH4MA21          = INVALID_HANDLE;

#endif // CONFIG_MQH
