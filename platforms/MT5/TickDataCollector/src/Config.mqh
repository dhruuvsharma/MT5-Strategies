#property strict

input string InpCSVFileName      = "";     // Output file (blank = auto: SYMBOL_ticks_YYYYMMDD.csv)
input bool   InpAppendMode       = false;  // Append to existing file instead of overwriting
input int    InpCandleMinutes    = 1;      // Candle window for running delta/OHLC context
input string InpSessionFilter    = "ALL";  // Write filter: ALL | Asian | London | London-NewYork | NewYork
input bool   InpPriceChangeOnly  = false;  // Skip ticks where price did not change
input int    InpFlushEveryN      = 500;    // Flush to disk every N ticks
