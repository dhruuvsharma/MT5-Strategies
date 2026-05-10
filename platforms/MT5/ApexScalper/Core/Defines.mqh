//+------------------------------------------------------------------+
//| Defines.mqh — APEX_SCALPER                                       |
//| All enums, structs, and constants. No logic lives here.          |
//| Import this file everywhere. Never define structs elsewhere.     |
//+------------------------------------------------------------------+


//--- Constants
#define APEX_MAX_TICK_BUFFER      5000    // Max ticks in TickCollector ring buffer
#define APEX_MAX_OB_SNAPSHOTS     50      // Max order book snapshots in ring buffer
#define APEX_MAX_VPIN_BUCKETS     50      // Max VPIN buckets retained
#define APEX_MAX_VP_NODES         2000    // Max price nodes in volume profile
#define APEX_MAX_FOOTPRINT_ROWS   500     // Max price rows per footprint candle
#define APEX_MAX_EVENT_SUBSCRIBERS 8      // Max subscribers per event type
#define APEX_MAX_SIGNAL_COUNT     10      // Max signal modules
#define APEX_MAX_OPEN_POSITIONS   10      // Max positions tracker can hold
#define APEX_SCORE_MAX            3.0     // Maximum signal score magnitude
#define APEX_SCORE_MIN           -3.0     // Minimum signal score magnitude
#define APEX_VALUE_AREA_PCT       0.70    // 70% of volume defines value area

//+------------------------------------------------------------------+
//| Tick struct — enriched with buy/sell classification              |
//+------------------------------------------------------------------+
struct ApexTick
{
    datetime  time;
    double    bid;
    double    ask;
    double    last;
    long      volume;
    int       direction;    // +1 buy-initiated, -1 sell-initiated, 0 unknown
    double    spread;
    long      index;        // global tick counter (monotonically increasing)
};

//+------------------------------------------------------------------+
//| Enriched candle built from tick stream                           |
//+------------------------------------------------------------------+
struct ApexCandle
{
    datetime  open_time;
    double    open;
    double    high;
    double    low;
    double    close;
    long      volume;
    long      buy_volume;
    long      sell_volume;
    long      tick_delta;          // buy_volume - sell_volume
    double    delta_efficiency;    // |tick_delta| / volume
    long      trade_count;
    double    avg_trade_size;
    double    tape_speed;          // trades per second during this candle
    double    max_spread;
    double    avg_spread;
    bool      is_complete;
};

//+------------------------------------------------------------------+
//| One price level inside a footprint candle                        |
//+------------------------------------------------------------------+
struct FootprintRow
{
    double    price;
    long      bid_vol;         // sell-initiated volume at this level
    long      ask_vol;         // buy-initiated volume at this level
    long      delta;           // ask_vol - bid_vol
    bool      bid_imbalance;   // bid_vol significantly > ask_vol
    bool      ask_imbalance;   // ask_vol significantly > bid_vol
    bool      zero_bid;        // bid_vol == 0 (full ask absorption)
    bool      zero_ask;        // ask_vol == 0 (full bid absorption)
};

//+------------------------------------------------------------------+
//| Full footprint for one candle                                    |
//+------------------------------------------------------------------+
struct FootprintCandle
{
    datetime     time;
    FootprintRow rows[APEX_MAX_FOOTPRINT_ROWS];
    int          row_count;
    int          stacked_bull_imbalance;  // max consecutive rows with zero_ask
    int          stacked_bear_imbalance;  // max consecutive rows with zero_bid
    double       poc_price;               // price level with max volume
    long         poc_volume;
    double       value_area_high;
    double       value_area_low;
    bool         is_complete;
};

//+------------------------------------------------------------------+
//| Single order book level                                          |
//+------------------------------------------------------------------+
struct OBLevel
{
    double  price;
    long    volume;
};

//+------------------------------------------------------------------+
//| Full order book snapshot                                         |
//+------------------------------------------------------------------+
struct OrderBookSnapshot
{
    datetime  time;
    OBLevel   bids[20];      // sorted descending by price
    OBLevel   asks[20];      // sorted ascending by price
    int       depth;
    double    mid_price;
    double    spread;
    double    obi_l1;
    double    obi_l3;
    double    obi_l5;
    double    obi_l10;
    double    weighted_obi;
    double    total_bid_vol;
    double    total_ask_vol;
    long      largest_bid_level_vol;
    double    largest_bid_price;
    long      largest_ask_level_vol;
    double    largest_ask_price;
    bool      spoof_suspected;    // true if large level appeared and vanished quickly
};

//+------------------------------------------------------------------+
//| Volume profile node — one price level in the window VP          |
//+------------------------------------------------------------------+
struct VPNode
{
    double  price;
    long    volume;
    long    buy_vol;
    long    sell_vol;
    bool    is_poc;
    bool    is_hvp;     // volume > HVP threshold
};

//+------------------------------------------------------------------+
//| Output from a single signal module                              |
//+------------------------------------------------------------------+
struct SignalResult
{
    string    signal_name;
    double    score;          // -3.0 to +3.0
    double    confidence;     // 0.0 to 1.0
    int       direction;      // +1 bullish, -1 bearish, 0 neutral
    bool      is_valid;       // false if stale or insufficient data
    datetime  generated_at;
    string    debug_note;
};

//+------------------------------------------------------------------+
//| Composite output from ScoringEngine                             |
//+------------------------------------------------------------------+
struct CompositeResult
{
    double       score;
    int          direction;
    int          signals_agree;
    int          signals_conflict;
    bool         conflict_flag;
    bool         trade_allowed;
    double       confidence;
    datetime     timestamp;
    SignalResult components[APEX_MAX_SIGNAL_COUNT];
    int          component_count;
};

//+------------------------------------------------------------------+
//| Context stored for each open trade                              |
//+------------------------------------------------------------------+
struct TradeContext
{
    ulong           ticket;
    ENUM_ORDER_TYPE type;
    double          entry_price;
    double          sl;
    double          tp;
    double          lot_size;
    CompositeResult signal_context;
    datetime        open_time;
    string          regime;
    double          spread_at_entry;
    bool            trailing_active;  // true once first HVP TP level is hit
};

//+------------------------------------------------------------------+
//| Market regime classification                                     |
//+------------------------------------------------------------------+
enum ApexRegime
{
    REGIME_TRENDING_BULL,
    REGIME_TRENDING_BEAR,
    REGIME_RANGING,
    REGIME_HIGH_VOLATILITY,
    REGIME_UNDEFINED
};

//+------------------------------------------------------------------+
//| Trading session classification                                   |
//+------------------------------------------------------------------+
enum TradingSession
{
    SESSION_ASIAN,
    SESSION_LONDON,
    SESSION_NEW_YORK,
    SESSION_LONDON_NY_OVERLAP,
    SESSION_OFF
};

//+------------------------------------------------------------------+
//| Event types for inter-module pub/sub                            |
//+------------------------------------------------------------------+
enum ApexEvent
{
    EVENT_NEW_BAR,
    EVENT_NEW_TICK,
    EVENT_OB_SNAPSHOT,
    EVENT_SIGNAL_GENERATED,
    EVENT_TRADE_OPENED,
    EVENT_TRADE_CLOSED,
    EVENT_REGIME_CHANGED,
    EVENT_KILL_SWITCH_ACTIVATED,
    EVENT_CONFLICT_DETECTED,
    EVENT_COUNT  // must be last — used to size arrays
};
