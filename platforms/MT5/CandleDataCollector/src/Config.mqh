#property strict

input string InpCSVFileName   = "";     // Output file (blank = auto: SYMBOL_Nmin_YYYYMMDD.csv)
input bool   InpAppendMode    = false;  // Append to existing file instead of overwriting
input int    InpCandleMinutes = 1;      // Candle timeframe in minutes
input string InpSessionFilter = "ALL";  // Write filter: ALL | Asian | London | London-NewYork | NewYork
input bool   InpWriteLastCandle = true; // Flush incomplete candle on shutdown
input bool   InpPrintEachCandle = false;// Echo each closed candle to the terminal
input int    InpFlushEveryN   = 10;     // Flush to disk every N candles (1 = after every candle)
