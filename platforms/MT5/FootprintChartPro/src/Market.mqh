//+------------------------------------------------------------------+
//| Market.mqh — FootprintChartPro                                    |
//| Tick processing, DOM data, historical bars, volume inference      |
//+------------------------------------------------------------------+
#ifndef MARKET_MQH
#define MARKET_MQH

#include "Config.mqh"

//+------------------------------------------------------------------+
//| Initialize indicator handles                                      |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   g_hRSI     = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   g_hMACD    = iMACD(_Symbol, _Period, Input_MACDFast, Input_MACDSlow, Input_MACDSignal, PRICE_CLOSE);
   g_hATR     = iATR(_Symbol, _Period, 14);
   g_hMA9     = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
   g_hMA21    = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_hMA50    = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
   g_hATRSlow = iATR(_Symbol, _Period, 50);
   g_hH4MA21  = iMA(_Symbol, PERIOD_H4, 21, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hRSI == INVALID_HANDLE || g_hMACD == INVALID_HANDLE ||
      g_hATR == INVALID_HANDLE || g_hMA9  == INVALID_HANDLE ||
      g_hMA21 == INVALID_HANDLE || g_hMA50 == INVALID_HANDLE ||
      g_hATRSlow == INVALID_HANDLE || g_hH4MA21 == INVALID_HANDLE)
   {
      Print("[", EA_NAME, "] Failed to create indicator handles. Error: ", GetLastError());
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Release indicator handles                                         |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
   if(g_hRSI     != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   if(g_hMACD    != INVALID_HANDLE) IndicatorRelease(g_hMACD);
   if(g_hATR     != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hMA9     != INVALID_HANDLE) IndicatorRelease(g_hMA9);
   if(g_hMA21    != INVALID_HANDLE) IndicatorRelease(g_hMA21);
   if(g_hMA50    != INVALID_HANDLE) IndicatorRelease(g_hMA50);
   if(g_hATRSlow != INVALID_HANDLE) IndicatorRelease(g_hATRSlow);
   if(g_hH4MA21  != INVALID_HANDLE) IndicatorRelease(g_hH4MA21);
}

//+------------------------------------------------------------------+
//| Get indicator value (single buffer, single bar)                   |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double val[];
   if(CopyBuffer(handle, buffer, shift, 1, val) != 1)
      return 0.0;
   return val[0];
}

//+------------------------------------------------------------------+
//| Get multiple indicator values                                     |
//+------------------------------------------------------------------+
int GetIndicatorValues(int handle, int buffer, int shift, int count, double &vals[])
{
   return CopyBuffer(handle, buffer, shift, count, vals);
}

//+------------------------------------------------------------------+
//| Volume Inference Engine                                           |
//| Estimates real volume from tick data for brokers without it       |
//+------------------------------------------------------------------+
long InferVolume(const MqlTick &tick, double prevBid)
{
   if(!Input_EnableVolumeInference)
      return (tick.volume > 0) ? tick.volume : 1;

   if(tick.volume > 0)
      return tick.volume;

   double priceChange = MathAbs(tick.bid - prevBid);
   double spreadFactor = (tick.ask - tick.bid) / _Point;

   long inferred = Input_BaseInferredVolume;

   // Scale by price movement
   if(priceChange > 0)
   {
      double pointMove = priceChange / _Point;
      inferred = (long)(Input_BaseInferredVolume * (1.0 + pointMove * Input_VolumeScaleFactor));
   }

   // Adjust by spread (tighter spread = more liquidity = higher volume)
   if(spreadFactor > 0 && spreadFactor < 50)
      inferred = (long)(inferred * (50.0 / spreadFactor) * 0.5);

   // Clamp
   if(inferred < Input_MinInferredVolume) inferred = Input_MinInferredVolume;
   if(inferred > Input_MaxInferredVolume) inferred = Input_MaxInferredVolume;

   return inferred;
}

//+------------------------------------------------------------------+
//| Classify tick direction                                           |
//| 1=buy (uptick), -1=sell (downtick), 0=neutral                    |
//+------------------------------------------------------------------+
int ClassifyTick(const MqlTick &tick, double prevBid)
{
   if(prevBid == 0.0)
      return 0;
   if(tick.bid > prevBid)
      return 1;   // Buy (uptick)
   if(tick.bid < prevBid)
      return -1;  // Sell (downtick)
   return 0;      // Neutral
}

//+------------------------------------------------------------------+
//| Get price bucket for a given price                                |
//+------------------------------------------------------------------+
double GetPriceBucket(double price)
{
   double bucketSize = Input_BucketPoints * _Point;
   return MathFloor(price / bucketSize) * bucketSize;
}

//+------------------------------------------------------------------+
//| Find or create price level in a footprint bar                     |
//+------------------------------------------------------------------+
int FindOrCreateLevel(FootprintBar &bar, double bucketPrice)
{
   // Search existing levels
   for(int i = 0; i < bar.levelCount; i++)
   {
      if(MathAbs(bar.levels[i].price - bucketPrice) < _Point * 0.5)
         return i;
   }

   // Create new level
   if(bar.levelCount >= ArraySize(bar.levels))
   {
      int newSize = bar.levelCount + 50;
      if(newSize > FP_MAX_LEVELS) newSize = FP_MAX_LEVELS;
      ArrayResize(bar.levels, newSize);
   }

   if(bar.levelCount >= FP_MAX_LEVELS)
      return bar.levelCount - 1;

   int idx = bar.levelCount;
   bar.levels[idx].price          = bucketPrice;
   bar.levels[idx].bidVolume      = 0;
   bar.levels[idx].askVolume      = 0;
   bar.levels[idx].buyVolume      = 0;
   bar.levels[idx].sellVolume     = 0;
   bar.levels[idx].delta          = 0;
   bar.levels[idx].imbalanceLevel = 0;
   bar.levels[idx].isBuyImbalance = false;
   bar.levelCount++;
   return idx;
}

//+------------------------------------------------------------------+
//| Process a single tick into the current footprint bar              |
//+------------------------------------------------------------------+
void ProcessTickIntoBar(FootprintBar &bar, const MqlTick &tick, int direction, long volume)
{
   double bucketPrice = GetPriceBucket(tick.bid);
   int lvlIdx = FindOrCreateLevel(bar, bucketPrice);

   if(direction == 1)
   {
      bar.levels[lvlIdx].buyVolume  += volume;
      bar.levels[lvlIdx].askVolume  += volume;
   }
   else if(direction == -1)
   {
      bar.levels[lvlIdx].sellVolume += volume;
      bar.levels[lvlIdx].bidVolume  += volume;
   }
   else
   {
      // Neutral — split evenly
      long half = volume / 2;
      bar.levels[lvlIdx].buyVolume  += half;
      bar.levels[lvlIdx].sellVolume += (volume - half);
   }

   bar.levels[lvlIdx].delta = bar.levels[lvlIdx].buyVolume - bar.levels[lvlIdx].sellVolume;
   bar.totalVolume += volume;
   bar.totalDelta   = 0;
   for(int i = 0; i < bar.levelCount; i++)
      bar.totalDelta += bar.levels[i].delta;
}

//+------------------------------------------------------------------+
//| Add tick to Time & Sales                                          |
//+------------------------------------------------------------------+
void AddTickToTimeAndSales(const MqlTick &tick, int direction, long volume)
{
   // Shift if at capacity
   if(g_tsTickCount >= Input_MaxTSHistory)
   {
      for(int i = 0; i < g_tsTickCount - 1; i++)
         g_tsTicks[i] = g_tsTicks[i + 1];
      g_tsTickCount--;
   }

   if(g_tsTickCount >= ArraySize(g_tsTicks))
      ArrayResize(g_tsTicks, g_tsTickCount + 100);

   g_tsTicks[g_tsTickCount].time       = tick.time;
   g_tsTicks[g_tsTickCount].price      = tick.bid;
   g_tsTicks[g_tsTickCount].volume     = volume;
   g_tsTicks[g_tsTickCount].direction  = direction;
   g_tsTicks[g_tsTickCount].isBigOrder = (volume >= Input_BigOrderThreshold);
   g_tsTickCount++;
}

//+------------------------------------------------------------------+
//| Calculate T&S bar totals for current bar                          |
//+------------------------------------------------------------------+
void CalculateTSBarTotals()
{
   g_tsBarBuyVolume  = 0;
   g_tsBarSellVolume = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);

   for(int i = 0; i < g_tsTickCount; i++)
   {
      if(g_tsTicks[i].time >= currentBarTime)
      {
         if(g_tsTicks[i].direction == 1)
            g_tsBarBuyVolume += g_tsTicks[i].volume;
         else if(g_tsTicks[i].direction == -1)
            g_tsBarSellVolume += g_tsTicks[i].volume;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate POC for a footprint bar                                 |
//+------------------------------------------------------------------+
void CalculateBarPOC(FootprintBar &bar)
{
   long maxVol = 0;
   bar.pocIndex = 0;
   for(int i = 0; i < bar.levelCount; i++)
   {
      long totalVol = bar.levels[i].buyVolume + bar.levels[i].sellVolume;
      if(totalVol > maxVol)
      {
         maxVol       = totalVol;
         bar.pocIndex = i;
         bar.poc      = bar.levels[i].price;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect imbalances in a footprint bar (3-tier diagonal)            |
//+------------------------------------------------------------------+
void DetectImbalances(FootprintBar &bar)
{
   // Sort levels by price ascending for diagonal comparison
   SortLevelsByPrice(bar);

   for(int i = 0; i < bar.levelCount; i++)
   {
      bar.levels[i].imbalanceLevel = 0;
      bar.levels[i].isBuyImbalance = false;

      // Diagonal: compare buy[i] vs sell[i+1] and sell[i] vs buy[i-1]
      if(i < bar.levelCount - 1)
      {
         long buyVol  = bar.levels[i].buyVolume;
         long sellVol = bar.levels[i + 1].sellVolume;

         if(sellVol > 0 && buyVol >= Input_MinImbalanceVolume)
         {
            double ratio = (double)buyVol / (double)sellVol;
            if(ratio >= Input_ImbalanceTier3Ratio)
            {
               bar.levels[i].imbalanceLevel = 3;
               bar.levels[i].isBuyImbalance = true;
            }
            else if(ratio >= Input_ImbalanceTier2Ratio)
            {
               bar.levels[i].imbalanceLevel = 2;
               bar.levels[i].isBuyImbalance = true;
            }
            else if(ratio >= Input_ImbalanceTier1Ratio)
            {
               bar.levels[i].imbalanceLevel = 1;
               bar.levels[i].isBuyImbalance = true;
            }
         }
      }

      if(i > 0 && bar.levels[i].imbalanceLevel == 0)
      {
         long sellVol = bar.levels[i].sellVolume;
         long buyVol  = bar.levels[i - 1].buyVolume;

         if(buyVol > 0 && sellVol >= Input_MinImbalanceVolume)
         {
            double ratio = (double)sellVol / (double)buyVol;
            if(ratio >= Input_ImbalanceTier3Ratio)
            {
               bar.levels[i].imbalanceLevel = 3;
               bar.levels[i].isBuyImbalance = false;
            }
            else if(ratio >= Input_ImbalanceTier2Ratio)
            {
               bar.levels[i].imbalanceLevel = 2;
               bar.levels[i].isBuyImbalance = false;
            }
            else if(ratio >= Input_ImbalanceTier1Ratio)
            {
               bar.levels[i].imbalanceLevel = 1;
               bar.levels[i].isBuyImbalance = false;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sort price levels by price ascending                              |
//+------------------------------------------------------------------+
void SortLevelsByPrice(FootprintBar &bar)
{
   for(int i = 0; i < bar.levelCount - 1; i++)
   {
      for(int j = i + 1; j < bar.levelCount; j++)
      {
         if(bar.levels[j].price < bar.levels[i].price)
         {
            PriceLevel tmp    = bar.levels[i];
            bar.levels[i]     = bar.levels[j];
            bar.levels[j]     = tmp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Load historical footprint data using CopyTicksRange               |
//+------------------------------------------------------------------+
void LoadHistoricalFootprintData()
{
   int barsToLoad = MathMin(Input_VisibleBars + 5, FP_MAX_BARS);
   ArrayResize(g_fpBars, barsToLoad);
   g_fpBarCount = 0;

   MqlRates rates[];
   int copied = CopyRates(_Symbol, _Period, 0, barsToLoad, rates);
   if(copied <= 0)
   {
      Print("[", EA_NAME, "] Failed to copy rates. Error: ", GetLastError());
      return;
   }

   int periodSec = PeriodSeconds(_Period);

   for(int b = 0; b < copied; b++)
   {
      int barIdx = g_fpBarCount;
      if(barIdx >= ArraySize(g_fpBars))
         ArrayResize(g_fpBars, barIdx + 20);

      g_fpBars[barIdx].time         = rates[b].time;
      g_fpBars[barIdx].open         = rates[b].open;
      g_fpBars[barIdx].high         = rates[b].high;
      g_fpBars[barIdx].low          = rates[b].low;
      g_fpBars[barIdx].close        = rates[b].close;
      g_fpBars[barIdx].levelCount   = 0;
      g_fpBars[barIdx].totalVolume  = 0;
      g_fpBars[barIdx].totalDelta   = 0;
      g_fpBars[barIdx].cumulativeDelta = 0;
      g_fpBars[barIdx].poc          = 0;
      g_fpBars[barIdx].pocIndex     = 0;
      g_fpBars[barIdx].isHistorical = (b < copied - 1);
      ArrayResize(g_fpBars[barIdx].levels, 50);

      // Fetch ticks for this bar
      MqlTick ticks[];
      datetime msStart = rates[b].time * 1000;
      datetime msEnd   = (b < copied - 1) ? rates[b + 1].time * 1000 : (datetime)(TimeCurrent() * 1000);

      int tickCount = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, (ulong)msStart, (ulong)msEnd);
      if(tickCount <= 0)
      {
         g_fpBarCount++;
         continue;
      }

      double prevBid = (tickCount > 0) ? ticks[0].bid : 0.0;
      for(int t = 0; t < tickCount; t++)
      {
         int direction = ClassifyTick(ticks[t], prevBid);
         long vol      = InferVolume(ticks[t], prevBid);
         ProcessTickIntoBar(g_fpBars[barIdx], ticks[t], direction, vol);
         prevBid = ticks[t].bid;
      }

      CalculateBarPOC(g_fpBars[barIdx]);
      if(g_fpBars[barIdx].isHistorical)
         DetectImbalances(g_fpBars[barIdx]);

      // Cumulative delta
      g_prevCumDelta += g_fpBars[barIdx].totalDelta;
      g_fpBars[barIdx].cumulativeDelta = g_prevCumDelta;

      g_fpBarCount++;
   }

   if(g_fpBarCount > 0)
      g_lastBarTime = g_fpBars[g_fpBarCount - 1].time;

   Print("[", EA_NAME, "] Loaded ", g_fpBarCount, " historical bars");
}

//+------------------------------------------------------------------+
//| Process incoming tick (called from OnTick)                        |
//+------------------------------------------------------------------+
void ProcessTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   int direction = ClassifyTick(tick, g_prevBid);
   long volume   = InferVolume(tick, g_prevBid);

   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != g_lastBarTime && g_lastBarTime != 0)
   {
      OnNewBar();
      g_lastBarTime = currentBarTime;
   }
   else if(g_lastBarTime == 0)
   {
      g_lastBarTime = currentBarTime;
   }

   // Process into current bar (last bar in array)
   if(g_fpBarCount > 0)
   {
      int curIdx = g_fpBarCount - 1;
      ProcessTickIntoBar(g_fpBars[curIdx], tick, direction, volume);

      // Update OHLC for live bar
      MqlRates rates[];
      if(CopyRates(_Symbol, _Period, 0, 1, rates) == 1)
      {
         g_fpBars[curIdx].open  = rates[0].open;
         g_fpBars[curIdx].high  = rates[0].high;
         g_fpBars[curIdx].low   = rates[0].low;
         g_fpBars[curIdx].close = rates[0].close;
      }

      CalculateBarPOC(g_fpBars[curIdx]);
      g_fpBars[curIdx].cumulativeDelta = g_prevCumDelta + g_fpBars[curIdx].totalDelta;
      g_footprintNeedsRedraw = true;
   }

   // Add to Time & Sales
   AddTickToTimeAndSales(tick, direction, volume);

   g_prevBid = tick.bid;
}

//+------------------------------------------------------------------+
//| Handle new bar formation                                          |
//+------------------------------------------------------------------+
void OnNewBar()
{
   // Lock previous bar
   if(g_fpBarCount > 0)
   {
      int prevIdx = g_fpBarCount - 1;
      DetectImbalances(g_fpBars[prevIdx]);
      g_fpBars[prevIdx].isHistorical = true;
      g_prevCumDelta = g_fpBars[prevIdx].cumulativeDelta;
   }

   // Add new bar
   if(g_fpBarCount >= ArraySize(g_fpBars))
      ArrayResize(g_fpBars, g_fpBarCount + 20);

   int newIdx = g_fpBarCount;
   g_fpBars[newIdx].time         = iTime(_Symbol, _Period, 0);
   g_fpBars[newIdx].open         = iOpen(_Symbol, _Period, 0);
   g_fpBars[newIdx].high         = iHigh(_Symbol, _Period, 0);
   g_fpBars[newIdx].low          = iLow(_Symbol, _Period, 0);
   g_fpBars[newIdx].close        = iClose(_Symbol, _Period, 0);
   g_fpBars[newIdx].levelCount   = 0;
   g_fpBars[newIdx].totalVolume  = 0;
   g_fpBars[newIdx].totalDelta   = 0;
   g_fpBars[newIdx].cumulativeDelta = g_prevCumDelta;
   g_fpBars[newIdx].poc          = 0;
   g_fpBars[newIdx].pocIndex     = 0;
   g_fpBars[newIdx].isHistorical = false;
   ArrayResize(g_fpBars[newIdx].levels, 50);
   g_fpBarCount++;

   // Trim old bars if too many
   if(g_fpBarCount > FP_MAX_BARS)
   {
      int shift = g_fpBarCount - FP_MAX_BARS;
      for(int i = 0; i < g_fpBarCount - shift; i++)
         g_fpBars[i] = g_fpBars[i + shift];
      g_fpBarCount -= shift;
   }

   g_footprintNeedsRedraw     = true;
   g_volumeProfileNeedsRedraw = true;
}

//+------------------------------------------------------------------+
//| Update DOM data from MarketBook                                   |
//+------------------------------------------------------------------+
void UpdateDOMData(MqlBookInfo &book[])
{
   int bookSize = ArraySize(book);
   if(bookSize == 0) return;

   g_domLevelCount = MathMin(bookSize, FP_MAX_DOM_LEVELS);
   if(ArraySize(g_domLevels) < g_domLevelCount)
      ArrayResize(g_domLevels, g_domLevelCount);

   for(int i = 0; i < g_domLevelCount; i++)
   {
      g_domLevels[i].price     = book[i].price;
      g_domLevels[i].flashBuy  = false;
      g_domLevels[i].flashSell = false;

      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
      {
         // Check for flash
         if(book[i].volume > g_domLevels[i].bidOrders && g_domLevels[i].bidOrders > 0)
            g_domLevels[i].flashBuy = true;
         g_domLevels[i].bidOrders = (long)book[i].volume;
         g_domLevels[i].askOrders = 0;
      }
      else
      {
         if(book[i].volume > g_domLevels[i].askOrders && g_domLevels[i].askOrders > 0)
            g_domLevels[i].flashSell = true;
         g_domLevels[i].askOrders = (long)book[i].volume;
         g_domLevels[i].bidOrders = 0;
      }

      g_domLevels[i].netDelta = g_domLevels[i].bidOrders - g_domLevels[i].askOrders;
   }
}

//+------------------------------------------------------------------+
//| Initialize DOM subscription                                       |
//+------------------------------------------------------------------+
bool InitializeDOMPanel()
{
   ArrayResize(g_domLevels, FP_MAX_DOM_LEVELS);
   g_domLevelCount = 0;

   if(!MarketBookAdd(_Symbol))
   {
      Print("[", EA_NAME, "] MarketBookAdd failed. DOM may not be available.");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Cleanup DOM subscription                                          |
//+------------------------------------------------------------------+
void CleanupDOMPanel()
{
   MarketBookRelease(_Symbol);
}

//+------------------------------------------------------------------+
//| Calculate Session Volume Profile                                  |
//+------------------------------------------------------------------+
void CalculateVolumeProfile()
{
   // Determine start bar based on mode
   int startBar = 0;
   int endBar   = 0;

   switch(Input_VPMode)
   {
      case VP_MODE_BAR_COUNT:
         endBar = MathMin(Input_VPBarCount, g_fpBarCount);
         break;

      case VP_MODE_FULL_DAY:
      {
         datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
         for(int i = g_fpBarCount - 1; i >= 0; i--)
         {
            if(g_fpBars[i].time >= today)
               endBar = g_fpBarCount - i;
            else
               break;
         }
         break;
      }

      case VP_MODE_SESSION_TIME:
      default:
         endBar = MathMin(Input_VPBarCount, g_fpBarCount);
         break;
   }

   if(endBar == 0) return;

   // Collect all price levels
   ArrayResize(g_vpLevels, 0);
   g_vpLevelCount = 0;

   for(int b = g_fpBarCount - endBar; b < g_fpBarCount; b++)
   {
      if(b < 0) continue;
      for(int l = 0; l < g_fpBars[b].levelCount; l++)
      {
         double price = g_fpBars[b].levels[l].price;
         int found = -1;

         for(int v = 0; v < g_vpLevelCount; v++)
         {
            if(MathAbs(g_vpLevels[v].price - price) < _Point * 0.5)
            {
               found = v;
               break;
            }
         }

         if(found >= 0)
         {
            g_vpLevels[found].totalVolume += g_fpBars[b].levels[l].buyVolume + g_fpBars[b].levels[l].sellVolume;
            g_vpLevels[found].buyVolume   += g_fpBars[b].levels[l].buyVolume;
            g_vpLevels[found].sellVolume  += g_fpBars[b].levels[l].sellVolume;
            g_vpLevels[found].delta       += g_fpBars[b].levels[l].delta;
         }
         else
         {
            g_vpLevelCount++;
            ArrayResize(g_vpLevels, g_vpLevelCount);
            g_vpLevels[g_vpLevelCount - 1].price       = price;
            g_vpLevels[g_vpLevelCount - 1].totalVolume  = g_fpBars[b].levels[l].buyVolume + g_fpBars[b].levels[l].sellVolume;
            g_vpLevels[g_vpLevelCount - 1].buyVolume    = g_fpBars[b].levels[l].buyVolume;
            g_vpLevels[g_vpLevelCount - 1].sellVolume   = g_fpBars[b].levels[l].sellVolume;
            g_vpLevels[g_vpLevelCount - 1].delta        = g_fpBars[b].levels[l].delta;
         }
      }
   }

   // Calculate POC, VAH, VAL
   CalculateProfilePOCVA();
}

//+------------------------------------------------------------------+
//| Calculate POC, VAH, VAL from volume profile                       |
//+------------------------------------------------------------------+
void CalculateProfilePOCVA()
{
   if(g_vpLevelCount == 0) return;

   // Find POC
   long maxVol = 0;
   int  pocIdx = 0;
   long totalVol = 0;

   for(int i = 0; i < g_vpLevelCount; i++)
   {
      totalVol += g_vpLevels[i].totalVolume;
      if(g_vpLevels[i].totalVolume > maxVol)
      {
         maxVol = g_vpLevels[i].totalVolume;
         pocIdx = i;
      }
   }

   g_sessionPOC = g_vpLevels[pocIdx].price;

   // Value Area (70% of total volume centered on POC)
   long vaTarget = (long)(totalVol * 0.70);
   long vaVol    = g_vpLevels[pocIdx].totalVolume;
   int  upper    = pocIdx;
   int  lower    = pocIdx;

   // Sort levels by price for VA calculation
   // Simple expand outward from POC
   while(vaVol < vaTarget)
   {
      long upperVol = (upper + 1 < g_vpLevelCount) ? g_vpLevels[upper + 1].totalVolume : 0;
      long lowerVol = (lower - 1 >= 0)              ? g_vpLevels[lower - 1].totalVolume : 0;

      if(upperVol >= lowerVol && upper + 1 < g_vpLevelCount)
      {
         upper++;
         vaVol += g_vpLevels[upper].totalVolume;
      }
      else if(lower - 1 >= 0)
      {
         lower--;
         vaVol += g_vpLevels[lower].totalVolume;
      }
      else
         break;
   }

   g_sessionVAH = g_vpLevels[upper].price;
   g_sessionVAL = g_vpLevels[lower].price;
}

//+------------------------------------------------------------------+
//| Detect Supply & Demand zones                                      |
//+------------------------------------------------------------------+
void DetectSupplyDemandZones()
{
   ArrayResize(g_zones, 0);
   g_zoneCount = 0;

   int swingLen = Input_SwingLength;
   int lookback = Input_ZoneLookback;

   for(int i = swingLen; i < lookback; i++)
   {
      // Swing high detection
      bool isSwingHigh = true;
      for(int j = 1; j <= swingLen; j++)
      {
         if(iHigh(_Symbol, _Period, i) <= iHigh(_Symbol, _Period, i - j) ||
            iHigh(_Symbol, _Period, i) <= iHigh(_Symbol, _Period, i + j))
         {
            isSwingHigh = false;
            break;
         }
      }

      if(isSwingHigh)
      {
         long swingVol = iVolume(_Symbol, _Period, i);
         long avgVol   = CalculateAverageVolume(i, 20);

         if(avgVol > 0 && swingVol > (long)(avgVol * Input_VolumeRatioFilter))
         {
            double atr = GetIndicatorValue(g_hATR, 0, i);
            if(atr > 0)
               AddZone(iHigh(_Symbol, _Period, i), atr, true, iTime(_Symbol, _Period, i));
         }
      }

      // Swing low detection
      bool isSwingLow = true;
      for(int j = 1; j <= swingLen; j++)
      {
         if(iLow(_Symbol, _Period, i) >= iLow(_Symbol, _Period, i - j) ||
            iLow(_Symbol, _Period, i) >= iLow(_Symbol, _Period, i + j))
         {
            isSwingLow = false;
            break;
         }
      }

      if(isSwingLow)
      {
         long swingVol = iVolume(_Symbol, _Period, i);
         long avgVol   = CalculateAverageVolume(i, 20);

         if(avgVol > 0 && swingVol > (long)(avgVol * Input_VolumeRatioFilter))
         {
            double atr = GetIndicatorValue(g_hATR, 0, i);
            if(atr > 0)
               AddZone(iLow(_Symbol, _Period, i), atr, false, iTime(_Symbol, _Period, i));
         }
      }
   }

   if(g_zoneCount > Input_MaxZones)
      g_zoneCount = Input_MaxZones;
}

//+------------------------------------------------------------------+
//| Add a supply/demand zone                                          |
//+------------------------------------------------------------------+
void AddZone(double pivotPrice, double atr, bool isSupply, datetime created)
{
   if(g_zoneCount >= FP_MAX_ZONES) return;

   g_zoneCount++;
   ArrayResize(g_zones, g_zoneCount);

   double width = atr * Input_ATRZoneWidthMultiplier;
   g_zones[g_zoneCount - 1].topPrice    = pivotPrice + width;
   g_zones[g_zoneCount - 1].bottomPrice = pivotPrice - width;
   g_zones[g_zoneCount - 1].isSupply    = isSupply;
   g_zones[g_zoneCount - 1].createdTime = created;
   g_zones[g_zoneCount - 1].isActive    = true;
}

//+------------------------------------------------------------------+
//| Calculate average volume over N bars                              |
//+------------------------------------------------------------------+
long CalculateAverageVolume(int startBar, int period)
{
   long total = 0;
   for(int i = startBar; i < startBar + period; i++)
      total += iVolume(_Symbol, _Period, i);
   return (period > 0) ? total / period : 0;
}

//+------------------------------------------------------------------+
//| Fetch economic calendar events                                    |
//+------------------------------------------------------------------+
void FetchEconomicCalendar()
{
   ArrayResize(g_calendarEvents, 0);
   g_calendarCount = 0;

   MqlCalendarValue values[];
   datetime from = TimeCurrent();
   datetime to   = from + (7 * 24 * 3600);

   if(CalendarValueHistory(values, from, to))
   {
      int count = MathMin(ArraySize(values), Input_CalendarMaxRows * 3);
      for(int i = 0; i < count; i++)
      {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
         {
            MqlCalendarCountry country;
            bool hasCountry = CalendarCountryById(event.country_id, country);

            g_calendarCount++;
            ArrayResize(g_calendarEvents, g_calendarCount);

            g_calendarEvents[g_calendarCount - 1].eventTime   = values[i].time;
            g_calendarEvents[g_calendarCount - 1].eventTitle   = event.name;
            g_calendarEvents[g_calendarCount - 1].importance   = (int)event.importance;
            g_calendarEvents[g_calendarCount - 1].currency     = hasCountry ? country.currency : "";
            g_calendarEvents[g_calendarCount - 1].country      = hasCountry ? country.code     : "";
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update mini session chart candles                                 |
//+------------------------------------------------------------------+
void UpdateMiniSessionChart()
{
   ArrayResize(g_sessionCandles, 0);
   g_sessionCandleCount = 0;

   // Parse session times
   MqlDateTime dtNow;
   TimeToStruct(TimeCurrent(), dtNow);

   string startParts[], endParts[];
   StringSplit(Input_SessionStartTime, ':', startParts);
   StringSplit(Input_SessionEndTime,   ':', endParts);

   if(ArraySize(startParts) < 2 || ArraySize(endParts) < 2) return;

   MqlDateTime dtStart = dtNow;
   dtStart.hour = (int)StringToInteger(startParts[0]);
   dtStart.min  = (int)StringToInteger(startParts[1]);
   dtStart.sec  = 0;
   datetime sessionStartDT = StructToTime(dtStart);

   MqlDateTime dtEnd = dtNow;
   dtEnd.hour = (int)StringToInteger(endParts[0]);
   dtEnd.min  = (int)StringToInteger(endParts[1]);
   dtEnd.sec  = 0;
   datetime sessionEndDT = StructToTime(dtEnd);

   int totalBars = iBars(_Symbol, PERIOD_M1);
   for(int i = 0; i < totalBars && i < 1440; i++)
   {
      datetime barTime = iTime(_Symbol, PERIOD_M1, i);
      if(barTime >= sessionStartDT && barTime <= sessionEndDT)
      {
         g_sessionCandleCount++;
         ArrayResize(g_sessionCandles, g_sessionCandleCount);

         int idx = g_sessionCandleCount - 1;
         g_sessionCandles[idx].time  = barTime;
         g_sessionCandles[idx].open  = iOpen(_Symbol, PERIOD_M1, i);
         g_sessionCandles[idx].high  = iHigh(_Symbol, PERIOD_M1, i);
         g_sessionCandles[idx].low   = iLow(_Symbol, PERIOD_M1, i);
         g_sessionCandles[idx].close = iClose(_Symbol, PERIOD_M1, i);
      }
   }
}

#endif // MARKET_MQH
