//+------------------------------------------------------------------+
//| Config.mqh — SwingTagEA                                         |
//| All inputs and compile-time constants. No logic.                |
//+------------------------------------------------------------------+
#ifndef SWINGTAGEA_CONFIG_MQH
#define SWINGTAGEA_CONFIG_MQH

//--- Inputs
input double InpLots             = 0.1;      // Trade volume (lots)
input int    InpSLPoints         = 2000;     // Stop Loss in points
input int    InpTPPoints         = 2000;     // Take Profit in points
input ulong  InpMagicNumber      = 123456;   // Unique EA identifier
input bool   InpOrderManagement  = true;     // Enable smart order management
input bool   InpUseTradingHours  = true;     // Enable trading hours filter
input string InpTradingStartTime = "13:00";  // Session start (HH:MM, broker time)
input string InpTradingEndTime   = "16:00";  // Session end   (HH:MM, broker time)

//--- EA identity
#define EA_NAME           "SwingTagEA"
#define EA_PREFIX         "[SwingTagEA] "

//--- Strategy constants
#define MIN_BARS_REQUIRED  4

//--- Chart object constants
#define HIGH_LINE_PREFIX  "HighLine"
#define LOW_LINE_PREFIX   "LowLine"
#define LINE_WIDTH         2

//--- Trade constants
#define ORDER_DEVIATION    5

#endif // SWINGTAGEA_CONFIG_MQH
