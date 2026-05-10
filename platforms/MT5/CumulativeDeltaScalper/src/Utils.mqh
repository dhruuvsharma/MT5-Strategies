//+------------------------------------------------------------------+
//| Utils.mqh — Dashboard, daily stats, logging helpers               |
//+------------------------------------------------------------------+
#ifndef UTILS_MQH
#define UTILS_MQH

#include "Trade.mqh"

//+------------------------------------------------------------------+
//| Get daily PnL and trade count from deal history                   |
//+------------------------------------------------------------------+
void GetDailyStats(double &todayPnL, int &todayTrades)
{
   todayPnL    = 0.0;
   todayTrades = 0;

   MqlDateTime today;
   TimeCurrent(today);
   today.hour = 0;
   today.min  = 0;
   today.sec  = 0;
   datetime dayStart = StructToTime(today);

   //--- Closed exits today (from history)
   if(HistorySelect(dayStart, TimeCurrent()))
   {
      int totalDeals = HistoryDealsTotal();
      for(int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;

         int entry = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
         {
            todayPnL += HistoryDealGetDouble(ticket, DEAL_PROFIT)
                      + HistoryDealGetDouble(ticket, DEAL_SWAP)
                      + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            todayTrades++;
         }
      }
   }

   //--- Plus any still-open position opened today (so the count doesn't dip while a trade runs)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_posInfo.SelectByIndex(i)) continue;
      if(g_posInfo.Symbol() != _Symbol || g_posInfo.Magic() != MagicNumber) continue;
      if(g_posInfo.Time() >= dayStart) todayTrades++;
   }
}

//+------------------------------------------------------------------+
//| Check if last closed trade was a loss, update cooldown timer      |
//+------------------------------------------------------------------+
void CheckLastTradeLoss()
{
   MqlDateTime today;
   TimeCurrent(today);
   today.hour = 0;
   today.min  = 0;
   today.sec  = 0;
   datetime dayStart = StructToTime(today);

   if(!HistorySelect(dayStart, TimeCurrent()))
      return;

   //--- Scan from most recent deal backwards
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      int entry = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         if(profit < 0.0)
         {
            datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            if(dealTime > g_lastLossTime)
               g_lastLossTime = dealTime;
         }
         break; // Only check the most recent exit
      }
   }
}

//+------------------------------------------------------------------+
//| Reset daily tracking at midnight                                  |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   MqlDateTime now;
   TimeCurrent(now);
   datetime today;
   now.hour = 0;
   now.min  = 0;
   now.sec  = 0;
   today = StructToTime(now);

   if(g_lastTradeDay != today)
   {
      g_lastTradeDay    = today;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dailyTradeCount = 0;
      g_dailyPnL        = 0.0;

      //--- Sync from history in case EA restarted mid-day
      GetDailyStats(g_dailyPnL, g_dailyTradeCount);

      Print(EA_PREFIX, "New trading day. Balance=", g_dayStartBalance,
            " Synced trades=", g_dailyTradeCount, " PnL=", g_dailyPnL);
   }
}

#ifdef BACKTEST_MODE
//=== BACKTEST_MODE: UI stubs (no chart objects, no rendering) ======
void CreateLabel(string n, int y, color c = clrWhite) {}
void InitDashboard() {}
void UpdateDashboard(string s) {}
void RemoveWindowObjects() {}
void DrawSlidingWindow() {}
void DisplayCandleDeltas() {}
color GetCellBgColor(int d, bool isPOC) { return clrBlack; }
color GetCellTxColor(int d) { return clrWhite; }
void BuildBarFootprint(int barIndex, datetime barTime, double barHigh,
                       int periodSec, double cellHeight, double basePrice) {}
void DisplayFootprint() {}
void RemoveDashboard() {}
#else
//+------------------------------------------------------------------+
//| Create a dashboard label object                                   |
//+------------------------------------------------------------------+
void CreateLabel(string name, int yOffset, color clr = clrWhite)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DASHBOARD_X);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, DASHBOARD_Y + yOffset);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, DASHBOARD_FONT_SIZE);
      ObjectSetString(0, name, OBJPROP_FONT, DASHBOARD_FONT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Initialize dashboard labels                                       |
//+------------------------------------------------------------------+
void InitDashboard()
{
   if(!ShowUI)
      return;

   string prefix = EA_NAME + "_dash_";
   ArrayResize(g_dashLabels, 9);
   g_dashLabels[0] = prefix + "title";
   g_dashLabels[1] = prefix + "cumdelta";
   g_dashLabels[2] = prefix + "livedelta";
   g_dashLabels[3] = prefix + "session";
   g_dashLabels[4] = prefix + "trades";
   g_dashLabels[5] = prefix + "pnl";
   g_dashLabels[6] = prefix + "spread";
   g_dashLabels[7] = prefix + "adx";
   g_dashLabels[8] = prefix + "status";

   for(int i = 0; i < ArraySize(g_dashLabels); i++)
      CreateLabel(g_dashLabels[i], i * DASHBOARD_LINE_HEIGHT);

   //--- Title
   ObjectSetString(0, g_dashLabels[0], OBJPROP_TEXT, "=== " + EA_NAME + " ===");
   ObjectSetInteger(0, g_dashLabels[0], OBJPROP_COLOR, clrGold);
}

//+------------------------------------------------------------------+
//| Update dashboard with current state                               |
//+------------------------------------------------------------------+
void UpdateDashboard(string status)
{
   if(!ShowUI)
      return;

   int cumDelta = CalculateCumDelta();
   int spread   = GetSpreadPoints();

   ObjectSetString(0, g_dashLabels[1], OBJPROP_TEXT,
      "CumDelta: " + IntegerToString(cumDelta) + " (window " + IntegerToString(g_bufferFilled) + "/" + IntegerToString(WindowSize) + ")");
   ObjectSetInteger(0, g_dashLabels[1], OBJPROP_COLOR,
      cumDelta > 0 ? clrLime : (cumDelta < 0 ? clrRed : clrWhite));

   ObjectSetString(0, g_dashLabels[2], OBJPROP_TEXT,
      "LiveDelta: " + IntegerToString(g_liveDelta) +
      " (up:" + IntegerToString(g_uptickCount) + " dn:" + IntegerToString(g_downtickCount) + ")");
   ObjectSetInteger(0, g_dashLabels[2], OBJPROP_COLOR, clrSilver);

   //--- Session line
   ObjectSetString(0, g_dashLabels[3], OBJPROP_TEXT,
      "Session: " + SessionName(g_currentSession) +
      "  W:" + IntegerToString(g_sessionWins) +
      "  L:" + IntegerToString(g_sessionLosses));
   ObjectSetInteger(0, g_dashLabels[3], OBJPROP_COLOR,
      g_currentSession == SESSION_NONE ? clrGray : clrAqua);

   //--- Trade counts (daily / session)
   ObjectSetString(0, g_dashLabels[4], OBJPROP_TEXT,
      "Trades: D " + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(MaxDailyTrades) +
      "   S " + IntegerToString(g_sessionTradeCount) + "/" + IntegerToString(MaxTradesPerSession));

   ObjectSetString(0, g_dashLabels[5], OBJPROP_TEXT,
      "PnL: " + DoubleToString(g_dailyPnL, 2));
   ObjectSetInteger(0, g_dashLabels[5], OBJPROP_COLOR,
      g_dailyPnL >= 0 ? clrLime : clrRed);

   //--- Spread current vs rolling avg
   double avgSpread = GetAvgSpread();
   ObjectSetString(0, g_dashLabels[6], OBJPROP_TEXT,
      "Spread: " + IntegerToString(spread) + " pts (avg " + DoubleToString(avgSpread, 1) + ")");
   ObjectSetInteger(0, g_dashLabels[6], OBJPROP_COLOR,
      spread <= MaxSpreadPoints ? clrWhite : clrOrangeRed);

   //--- ADX
   double adx = GetADX();
   ObjectSetString(0, g_dashLabels[7], OBJPROP_TEXT,
      "ADX(M15): " + DoubleToString(adx, 1) + " (need " + DoubleToString(ADXThreshold, 1) + ")");
   ObjectSetInteger(0, g_dashLabels[7], OBJPROP_COLOR,
      adx >= ADXThreshold ? clrLime : clrSilver);

   ObjectSetString(0, g_dashLabels[8], OBJPROP_TEXT,
      "Status: " + status);
   ObjectSetInteger(0, g_dashLabels[8], OBJPROP_COLOR,
      StringFind(status, "ACTIVE") == 0 ? clrLime : clrOrangeRed);

   //--- Draw sliding window rectangle, per-candle deltas, and footprint
   DrawSlidingWindow();
   DisplayCandleDeltas();
   DisplayFootprint();

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove sliding window chart objects (by prefix)                   |
//+------------------------------------------------------------------+
void RemoveWindowObjects()
{
   ObjectDelete(0, SW_RECT_NAME);
   ObjectDelete(0, SW_LIVE_DELTA_NAME);
   ObjectDelete(0, SW_CUMDELTA_NAME);
   ObjectsDeleteAll(0, SW_DELTA_PREFIX);
   ObjectsDeleteAll(0, SW_FP_BG_PREFIX);
   ObjectsDeleteAll(0, SW_FP_TX_PREFIX);
}

//+------------------------------------------------------------------+
//| Draw sliding window rectangle around the N candles                |
//+------------------------------------------------------------------+
void DrawSlidingWindow()
{
   int count = MathMin(g_bufferFilled, WindowSize);
   if(count < 1)
      return;

   //--- Window covers bars 1..count (bar 0 = current live candle)
   //--- Include bar 0 for live context
   int barStart = count;  // oldest bar in window
   int barEnd   = 0;      // current bar

   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, barStart + 1, rates) < barStart + 1)
      return;
   ArraySetAsSeries(rates, true);

   //--- Find high/low across the window
   double hi = rates[0].high;
   double lo = rates[0].low;
   for(int i = 0; i <= barStart; i++)
   {
      if(rates[i].high > hi) hi = rates[i].high;
      if(rates[i].low  < lo) lo = rates[i].low;
   }

   //--- Add small padding
   double padding = (hi - lo) * 0.05;
   hi += padding;
   lo -= padding;

   datetime startTime = rates[barStart].time;
   datetime endTime   = rates[barEnd].time + PeriodSeconds(PERIOD_CURRENT);

   //--- Color based on cumulative delta
   int cumDelta = CalculateCumDelta();
   color rectColor = (cumDelta > 0) ? clrLime : (cumDelta < 0 ? clrRed : clrGray);

   if(ObjectFind(0, SW_RECT_NAME) < 0)
   {
      ObjectCreate(0, SW_RECT_NAME, OBJ_RECTANGLE, 0, startTime, lo, endTime, hi);
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_COLOR, rectColor);
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_FILL, false);
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_WIDTH, SW_RECT_WIDTH);
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_STYLE, SW_RECT_STYLE);
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_BACK, true);
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_TIME,  0, startTime);
      ObjectSetDouble (0, SW_RECT_NAME, OBJPROP_PRICE, 0, lo);
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_TIME,  1, endTime);
      ObjectSetDouble (0, SW_RECT_NAME, OBJPROP_PRICE, 1, hi);
      ObjectSetInteger(0, SW_RECT_NAME, OBJPROP_COLOR, rectColor);
   }
}

//+------------------------------------------------------------------+
//| Display per-candle delta values below each bar + live delta       |
//+------------------------------------------------------------------+
void DisplayCandleDeltas()
{
   //--- Clean old delta labels
   ObjectsDeleteAll(0, SW_DELTA_PREFIX);
   ObjectDelete(0, SW_LIVE_DELTA_NAME);
   ObjectDelete(0, SW_CUMDELTA_NAME);

   int deltas[];
   int count = GetOrderedDeltas(deltas);

   //--- Need rates to position text below candles
   int barsNeeded = count + 1; // +1 for current bar (bar 0)
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, barsNeeded, rates) < barsNeeded)
      return;
   ArraySetAsSeries(rates, true);

   //--- Find a consistent offset below the low for text placement
   double atr = GetATR();
   double textOffset = (atr > 0) ? atr * 0.3 : 10 * _Point;

   //--- Display finalized candle deltas (bars 1..count)
   //--- deltas[0] = oldest, deltas[count-1] = newest (bar 1)
   for(int i = 0; i < count; i++)
   {
      int bar = count - i; // deltas[0]→bar count, deltas[count-1]→bar 1
      string name = SW_DELTA_PREFIX + IntegerToString(i);

      double yPos = rates[bar].low - textOffset;

      ObjectCreate(0, name, OBJ_TEXT, 0, rates[bar].time, yPos);
      ObjectSetString (0, name, OBJPROP_TEXT, IntegerToString(deltas[i]));
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, SW_TEXT_SIZE);
      ObjectSetString (0, name, OBJPROP_FONT, DASHBOARD_FONT);
      ObjectSetInteger(0, name, OBJPROP_COLOR,
         deltas[i] > 0 ? clrLime : (deltas[i] < 0 ? clrRed : clrGray));
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }

   //--- Display live delta on current bar (bar 0)
   double yPosLive = rates[0].low - textOffset;
   ObjectCreate(0, SW_LIVE_DELTA_NAME, OBJ_TEXT, 0, rates[0].time, yPosLive);
   ObjectSetString (0, SW_LIVE_DELTA_NAME, OBJPROP_TEXT, IntegerToString(g_liveDelta) + "*");
   ObjectSetInteger(0, SW_LIVE_DELTA_NAME, OBJPROP_FONTSIZE, SW_TEXT_SIZE);
   ObjectSetString (0, SW_LIVE_DELTA_NAME, OBJPROP_FONT, DASHBOARD_FONT);
   ObjectSetInteger(0, SW_LIVE_DELTA_NAME, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, SW_LIVE_DELTA_NAME, OBJPROP_ANCHOR, ANCHOR_UPPER);
   ObjectSetInteger(0, SW_LIVE_DELTA_NAME, OBJPROP_SELECTABLE, false);

   //--- Display cumulative delta sum below the window
   if(count > 0)
   {
      int cumDelta = CalculateCumDelta();
      //--- Position at the midpoint of the window, further below
      int midBar   = count / 2;
      double yPosCum = rates[midBar].low - textOffset * 2.5;

      ObjectCreate(0, SW_CUMDELTA_NAME, OBJ_TEXT, 0, rates[midBar].time, yPosCum);
      ObjectSetString (0, SW_CUMDELTA_NAME, OBJPROP_TEXT,
         StringFormat("\x03A3: %d (Th: +/-%d)", cumDelta, DeltaThreshold));
      ObjectSetInteger(0, SW_CUMDELTA_NAME, OBJPROP_FONTSIZE, SW_TEXT_SIZE + 1);
      ObjectSetString (0, SW_CUMDELTA_NAME, OBJPROP_FONT, DASHBOARD_FONT);
      ObjectSetInteger(0, SW_CUMDELTA_NAME, OBJPROP_COLOR,
         cumDelta > DeltaThreshold ? clrLime :
         (cumDelta < -DeltaThreshold ? clrRed : clrWhite));
      ObjectSetInteger(0, SW_CUMDELTA_NAME, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, SW_CUMDELTA_NAME, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Get cell background color based on delta value                    |
//+------------------------------------------------------------------+
color GetCellBgColor(int delta, bool isPOC)
{
   if(isPOC)
      return C'128,0,128';    // Purple for point of control (highest volume)
   if(delta > 0)
      return C'139,119,42';   // Dark gold for positive delta
   if(delta < 0)
      return C'139,35,35';    // Dark red for negative delta
   return C'80,80,80';        // Dark gray for zero
}

//+------------------------------------------------------------------+
//| Get cell text color based on delta value                          |
//+------------------------------------------------------------------+
color GetCellTxColor(int delta)
{
   if(delta > 0)
      return clrWhite;
   if(delta < 0)
      return clrRed;
   return clrGray;
}

//+------------------------------------------------------------------+
//| Build footprint cells for one candle above the bar                |
//| Fetches ticks, buckets by price level, draws bg rect + text       |
//+------------------------------------------------------------------+
void BuildBarFootprint(int barIndex, datetime barTime, double barHigh,
                       int periodSec, double cellHeight, double basePrice)
{
   //--- Time range for tick query (milliseconds)
   ulong msStart = (ulong)barTime * 1000;
   ulong msEnd;
   if(barIndex == 0)
      msEnd = (ulong)TimeCurrent() * 1000;
   else
      msEnd = msStart + (ulong)periodSec * 1000 - 1;

   MqlTick ticks[];
   int tickCount = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, msStart, msEnd);
   if(tickCount < 2)
      return;

   //--- Block size in price
   double blockSize = FootprintBlockPips * 10.0 * _Point;
   if(blockSize <= 0)
      return;

   //--- Find tick price range
   double lo = ticks[0].bid;
   double hi = ticks[0].bid;
   for(int t = 1; t < tickCount; t++)
   {
      if(ticks[t].bid < lo) lo = ticks[t].bid;
      if(ticks[t].bid > hi) hi = ticks[t].bid;
   }

   //--- Round to block boundaries
   double blockLow  = MathFloor(lo / blockSize) * blockSize;
   double blockHigh = MathCeil(hi / blockSize) * blockSize;
   if(blockHigh <= blockLow)
      blockHigh = blockLow + blockSize;
   int numBlocks = (int)MathRound((blockHigh - blockLow) / blockSize);
   if(numBlocks < 1) numBlocks = 1;
   if(numBlocks > SW_FP_MAX_LEVELS) return;

   //--- Count buy/sell per block
   int deltaArr[];
   int totalArr[];
   ArrayResize(deltaArr, numBlocks);
   ArrayResize(totalArr, numBlocks);
   ArrayInitialize(deltaArr, 0);
   ArrayInitialize(totalArr, 0);

   for(int t = 1; t < tickCount; t++)
   {
      int blockIdx = (int)MathFloor((ticks[t].bid - blockLow) / blockSize);
      if(blockIdx < 0) blockIdx = 0;
      if(blockIdx >= numBlocks) blockIdx = numBlocks - 1;

      if(ticks[t].bid > ticks[t - 1].bid)
      {
         deltaArr[blockIdx]++;
         totalArr[blockIdx]++;
      }
      else if(ticks[t].bid < ticks[t - 1].bid)
      {
         deltaArr[blockIdx]--;
         totalArr[blockIdx]++;
      }
   }

   //--- Find POC (level with highest total volume)
   int pocIdx = 0;
   int pocVol = 0;
   for(int k = 0; k < numBlocks; k++)
   {
      if(totalArr[k] > pocVol)
      {
         pocVol = totalArr[k];
         pocIdx = k;
      }
   }

   //--- Draw cells above the candle
   //--- Stack from bottom (level 0) to top (level N)
   //--- basePrice = starting Y for the bottom of the footprint column
   datetime barEnd = barTime + (datetime)periodSec;

   for(int k = 0; k < numBlocks; k++)
   {
      if(totalArr[k] == 0)
         continue;

      double cellLo = basePrice + k * cellHeight;
      double cellHi = cellLo + cellHeight;
      bool isPOC = (k == pocIdx);

      string bgName = SW_FP_BG_PREFIX + IntegerToString(barIndex) + "_" + IntegerToString(k);
      string txName = SW_FP_TX_PREFIX + IntegerToString(barIndex) + "_" + IntegerToString(k);

      //--- Background rectangle
      ObjectCreate(0, bgName, OBJ_RECTANGLE, 0, barTime, cellLo, barEnd, cellHi);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, GetCellBgColor(deltaArr[k], isPOC));
      ObjectSetInteger(0, bgName, OBJPROP_FILL, true);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);

      //--- Delta text centered in cell
      double cellMid = (cellLo + cellHi) / 2.0;
      datetime timeMid = barTime + (datetime)(periodSec / 2);

      ObjectCreate(0, txName, OBJ_TEXT, 0, timeMid, cellMid);
      ObjectSetString (0, txName, OBJPROP_TEXT,
         (deltaArr[k] > 0 ? "+" : "") + IntegerToString(deltaArr[k]));
      ObjectSetInteger(0, txName, OBJPROP_FONTSIZE, 7);
      ObjectSetString (0, txName, OBJPROP_FONT, DASHBOARD_FONT);
      ObjectSetInteger(0, txName, OBJPROP_COLOR, GetCellTxColor(deltaArr[k]));
      ObjectSetInteger(0, txName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, txName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, txName, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Display footprint for all candles in the sliding window           |
//+------------------------------------------------------------------+
void DisplayFootprint()
{
   //--- Clean old footprint objects
   ObjectsDeleteAll(0, SW_FP_BG_PREFIX);
   ObjectsDeleteAll(0, SW_FP_TX_PREFIX);

   int count = MathMin(g_bufferFilled, WindowSize);

   int barsNeeded = count + 1;
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, barsNeeded, rates) < barsNeeded)
      return;
   ArraySetAsSeries(rates, true);

   int periodSec = PeriodSeconds(PERIOD_CURRENT);
   double atr = GetATR();

   //--- Cell height in price space for the display stack
   double cellHeight = (atr > 0) ? atr * 0.07 : FootprintBlockPips * 10.0 * _Point;

   //--- Gap above candle high
   double gap = (atr > 0) ? atr * 0.1 : 5 * _Point;

   //--- Build footprint for each bar in window (including live bar 0)
   for(int b = 0; b <= count; b++)
   {
      double basePrice = rates[b].high + gap;
      BuildBarFootprint(b, rates[b].time, rates[b].high, periodSec, cellHeight, basePrice);
   }
}

//+------------------------------------------------------------------+
//| Remove all dashboard objects                                      |
//+------------------------------------------------------------------+
void RemoveDashboard()
{
   for(int i = 0; i < ArraySize(g_dashLabels); i++)
      ObjectDelete(0, g_dashLabels[i]);

   RemoveWindowObjects();
}
#endif // BACKTEST_MODE

#endif // UTILS_MQH
