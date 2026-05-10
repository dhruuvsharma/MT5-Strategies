//+------------------------------------------------------------------+
//| Signal.mqh — FootprintChartPro                                    |
//| Signal meter, chart analyst report, analysis logic                |
//+------------------------------------------------------------------+
#ifndef SIGNAL_MQH
#define SIGNAL_MQH

#include "Config.mqh"
#include "Market.mqh"

//+------------------------------------------------------------------+
//| Check POC acceptance (price tested POC for N bars within range)   |
//+------------------------------------------------------------------+
bool CheckPOCAcceptance()
{
   int acceptanceBars = Input_POCAcceptanceBars;
   double acceptanceDist = Input_POCAcceptanceDistance * _Point;

   int testCount = 0;
   for(int i = 0; i < acceptanceBars && i < g_fpBarCount; i++)
   {
      int idx = g_fpBarCount - 1 - i;
      if(idx < 0) break;
      if(MathAbs(g_fpBars[idx].close - g_sessionPOC) <= acceptanceDist)
         testCount++;
   }

   return (testCount >= acceptanceBars);
}

//+------------------------------------------------------------------+
//| Calculate composite signal meter value (-100 to +100)             |
//+------------------------------------------------------------------+
double CalculateSignalMeterValue()
{
   double signal = 0.0;

   double ma9  = GetIndicatorValue(g_hMA9,  0, 0);
   double ma21 = GetIndicatorValue(g_hMA21, 0, 0);
   double ma50 = GetIndicatorValue(g_hMA50, 0, 0);
   double currentPrice = iClose(_Symbol, _Period, 0);

   //--- Factor 1: MA Alignment (max +/-45)
   int maAlignment = 0;
   if(currentPrice > ma9 && ma9 > ma21 && ma21 > ma50)      maAlignment =  3;
   else if(currentPrice > ma9 && ma9 > ma21)                 maAlignment =  2;
   else if(currentPrice > ma9)                               maAlignment =  1;
   else if(currentPrice < ma9 && ma9 < ma21 && ma21 < ma50) maAlignment = -3;
   else if(currentPrice < ma9 && ma9 < ma21)                 maAlignment = -2;
   else if(currentPrice < ma9)                               maAlignment = -1;

   signal += maAlignment * 15.0;

   //--- Factor 2: ATR Regime (trending amplifies, ranging dampens)
   double atr     = GetIndicatorValue(g_hATR,     0, 0);
   double atrSlow = GetIndicatorValue(g_hATRSlow, 0, 0);

   if(atrSlow > 0)
   {
      double atrRatio = atr / atrSlow;
      if(atrRatio > Input_ATRTrendThreshold)
         signal *= 1.3;
      else
         signal *= 0.7;
   }

   //--- Factor 3: POC Acceptance (+/-10)
   if(CheckPOCAcceptance())
   {
      if(currentPrice > g_sessionPOC) signal += 10.0;
      else if(currentPrice < g_sessionPOC) signal -= 10.0;
   }

   //--- Factor 4: Volume Bias (+/-20)
   if(g_fpBarCount > 0)
   {
      int curIdx = g_fpBarCount - 1;
      long buyVol = 0, sellVol = 0;
      for(int i = 0; i < g_fpBars[curIdx].levelCount; i++)
      {
         buyVol  += g_fpBars[curIdx].levels[i].buyVolume;
         sellVol += g_fpBars[curIdx].levels[i].sellVolume;
      }
      if(buyVol + sellVol > 0)
      {
         double volumeRatio = (double)buyVol / (buyVol + sellVol);
         signal += (volumeRatio - 0.5) * 40.0;
      }
   }

   // Clamp
   if(signal > 100.0)  signal = 100.0;
   if(signal < -100.0) signal = -100.0;

   return signal;
}

//+------------------------------------------------------------------+
//| Generate full Chart Analyst report (9 sections)                   |
//+------------------------------------------------------------------+
void GenerateChartAnalystReport()
{
   double currentPrice = iClose(_Symbol, _Period, 0);
   double ma9   = GetIndicatorValue(g_hMA9,  0, 0);
   double ma21  = GetIndicatorValue(g_hMA21, 0, 0);
   double ma50  = GetIndicatorValue(g_hMA50, 0, 0);
   double atr   = GetIndicatorValue(g_hATR,  0, 0);
   double h4Close = iClose(_Symbol, PERIOD_H4, 0);
   double h4MA21  = GetIndicatorValue(g_hH4MA21, 0, 0);

   //--- Section 0: PAIR INFO
   double dailyChange = iClose(_Symbol, PERIOD_D1, 0) - iOpen(_Symbol, PERIOD_D1, 0);
   double dailyPct    = (iOpen(_Symbol, PERIOD_D1, 0) != 0) ? (dailyChange / iOpen(_Symbol, PERIOD_D1, 0)) * 100.0 : 0;

   g_analystSections[0].title     = "PAIR INFO";
   g_analystSections[0].content   = StringFormat("%s | %s | Daily: %+.1f pts (%+.2f%%)",
                                       _Symbol, EnumToString(_Period), dailyChange / _Point, dailyPct);
   g_analystSections[0].textColor = (dailyChange > 0) ? g_BullishTextColor : g_BearishTextColor;

   //--- Section 1: TREND + HIGHER TF | ATR
   string trendText = "";
   color  trendColor = g_NeutralTextColor;

   if(currentPrice > ma9 && ma9 > ma21 && ma21 > ma50)
   {  trendText = "Strong bullish bias. All MAs aligned."; trendColor = g_BullishTextColor; }
   else if(currentPrice > ma9 && ma9 > ma21)
   {  trendText = "Moderate bullish bias. Price above MA9/21."; trendColor = g_BullishTextColor; }
   else if(currentPrice < ma9 && ma9 < ma21 && ma21 < ma50)
   {  trendText = "Strong bearish bias. All MAs inverted."; trendColor = g_BearishTextColor; }
   else if(currentPrice < ma9 && ma9 < ma21)
   {  trendText = "Moderate bearish bias. Price below MA9/21."; trendColor = g_BearishTextColor; }
   else
   {  trendText = "Choppy. Mixed MA signals."; }

   string htfText = (h4Close > h4MA21) ? "H4 bullish." : "H4 bearish.";

   g_analystSections[1].title     = "TREND + HIGHER TF | ATR: " + DoubleToString(atr / _Point, 0) + " pts";
   g_analystSections[1].content   = trendText + " " + htfText;
   g_analystSections[1].textColor = trendColor;

   //--- Section 2: DOM ANALYSIS
   long totalBids = 0, totalAsks = 0;
   int nearLevels = MathMin(5, g_domLevelCount);
   for(int i = 0; i < nearLevels; i++)
   {
      totalBids += g_domLevels[i].bidOrders;
      totalAsks += g_domLevels[i].askOrders;
   }

   double bidAskRatio = (totalAsks > 0) ? (double)totalBids / totalAsks : 1.0;
   string domText = "";
   color  domColor = g_NeutralTextColor;

   if(bidAskRatio > 1.5)
   {  domText = StringFormat("Heavy bid support (%.1f:1). Near levels favor bulls.", bidAskRatio); domColor = g_BullishTextColor; }
   else if(bidAskRatio > 1.2)
   {  domText = StringFormat("Moderate bid pressure (%.1f:1).", bidAskRatio); domColor = g_BullishTextColor; }
   else if(bidAskRatio < 0.67)
   {  domText = StringFormat("Heavy ask pressure (1:%.1f). Near levels favor bears.", 1.0/bidAskRatio); domColor = g_BearishTextColor; }
   else if(bidAskRatio < 0.83)
   {  domText = StringFormat("Moderate ask pressure (1:%.1f).", 1.0/bidAskRatio); domColor = g_BearishTextColor; }
   else
   {  domText = "Balanced book. Near levels neutral."; }

   g_analystSections[2].title     = "DOM ANALYSIS";
   g_analystSections[2].content   = domText;
   g_analystSections[2].textColor = domColor;

   //--- Section 3: TIME & SALES
   CalculateTSBarTotals();
   double buyPercent = (g_tsBarBuyVolume + g_tsBarSellVolume > 0)
                     ? (double)g_tsBarBuyVolume / (g_tsBarBuyVolume + g_tsBarSellVolume) * 100.0
                     : 50.0;

   string tapeText = "";
   color  tapeColor = g_NeutralTextColor;

   if(buyPercent > 60)
   {  tapeText = StringFormat("Aggressive buying (%.0f%%). Buyers lifting offers.", buyPercent); tapeColor = g_BullishTextColor; }
   else if(buyPercent > 55)
   {  tapeText = StringFormat("Moderate buy pressure (%.0f%%).", buyPercent); tapeColor = g_BullishTextColor; }
   else if(buyPercent < 40)
   {  tapeText = StringFormat("Aggressive selling (%.0f%% sell). Sellers hitting bids.", 100.0 - buyPercent); tapeColor = g_BearishTextColor; }
   else if(buyPercent < 45)
   {  tapeText = StringFormat("Moderate sell pressure (%.0f%% sell).", 100.0 - buyPercent); tapeColor = g_BearishTextColor; }
   else
   {  tapeText = "Balanced tape. Buy/Sell near 50/50."; }

   g_analystSections[3].title     = "TIME & SALES";
   g_analystSections[3].content   = tapeText;
   g_analystSections[3].textColor = tapeColor;

   //--- Section 4: ORDER FLOW
   long barDelta = 0;
   if(g_fpBarCount > 0)
      barDelta = g_fpBars[g_fpBarCount - 1].totalDelta;

   string flowText = "";
   color  flowColor = g_NeutralTextColor;

   if(barDelta > 1000)
   {  flowText = "Active aggressive buying. Delta positive, cumDelta rising."; flowColor = g_BullishTextColor; }
   else if(barDelta > 300)
   {  flowText = "Moderate buying pressure. Delta positive."; flowColor = g_BullishTextColor; }
   else if(barDelta < -1000)
   {  flowText = "Active aggressive selling. Delta negative, cumDelta falling."; flowColor = g_BearishTextColor; }
   else if(barDelta < -300)
   {  flowText = "Moderate selling pressure. Delta negative."; flowColor = g_BearishTextColor; }
   else
   {  flowText = "Balanced flow. No clear directional aggression."; }

   g_analystSections[4].title     = "ORDER FLOW";
   g_analystSections[4].content   = flowText;
   g_analystSections[4].textColor = flowColor;

   //--- Section 5: VOLUME
   long barBuyVol = 0, barSellVol = 0;
   if(g_fpBarCount > 0)
   {
      int ci = g_fpBarCount - 1;
      for(int i = 0; i < g_fpBars[ci].levelCount; i++)
      {
         barBuyVol  += g_fpBars[ci].levels[i].buyVolume;
         barSellVol += g_fpBars[ci].levels[i].sellVolume;
      }
   }

   double volRatio = (barSellVol > 0) ? (double)barBuyVol / barSellVol : 1.0;
   string volumeText = "";
   color  volumeColor = g_NeutralTextColor;

   if(volRatio > 2.0)
   {  volumeText = StringFormat("Extreme buy volume (ratio: %.2f). Heavy buyer dominance.", volRatio); volumeColor = g_BullishTextColor; }
   else if(volRatio > 1.3)
   {  volumeText = StringFormat("Elevated buy volume (ratio: %.2f). Buyers dominant.", volRatio); volumeColor = g_BullishTextColor; }
   else if(volRatio < 0.5)
   {  volumeText = StringFormat("Extreme sell volume (ratio: %.2f). Heavy seller dominance.", volRatio); volumeColor = g_BearishTextColor; }
   else if(volRatio < 0.77)
   {  volumeText = StringFormat("Elevated sell volume (ratio: %.2f). Sellers dominant.", volRatio); volumeColor = g_BearishTextColor; }
   else
   {  volumeText = StringFormat("Balanced volume (ratio: %.2f). Neither side dominant.", volRatio); }

   g_analystSections[5].title     = "VOLUME";
   g_analystSections[5].content   = volumeText;
   g_analystSections[5].textColor = volumeColor;

   //--- Section 6: IMBALANCES
   int buyImb = 0, sellImb = 0;
   int lookbackBars = MathMin(10, g_fpBarCount);
   for(int b = g_fpBarCount - lookbackBars; b < g_fpBarCount; b++)
   {
      if(b < 0) continue;
      for(int l = 0; l < g_fpBars[b].levelCount; l++)
      {
         if(g_fpBars[b].levels[l].imbalanceLevel > 0)
         {
            if(g_fpBars[b].levels[l].isBuyImbalance) buyImb++;
            else sellImb++;
         }
      }
   }

   string imbText = "";
   color  imbColor = g_NeutralTextColor;

   if(buyImb > sellImb * 2)
   {  imbText = StringFormat("Buy imb: %d | Sell imb: %d. Institutional buying likely.", buyImb, sellImb); imbColor = g_BullishTextColor; }
   else if(sellImb > buyImb * 2)
   {  imbText = StringFormat("Buy imb: %d | Sell imb: %d. Institutional selling likely.", buyImb, sellImb); imbColor = g_BearishTextColor; }
   else
   {  imbText = StringFormat("Buy imb: %d | Sell imb: %d. Mixed institutional activity.", buyImb, sellImb); }

   g_analystSections[6].title     = "IMBALANCES";
   g_analystSections[6].content   = imbText;
   g_analystSections[6].textColor = imbColor;

   //--- Section 7: KEY LEVELS
   double dailyHigh = iHigh(_Symbol, PERIOD_D1, 0);
   double dailyLow  = iLow(_Symbol,  PERIOD_D1, 0);

   g_analystSections[7].title     = "KEY LEVELS";
   g_analystSections[7].content   = StringFormat("Session POC: %s | Daily: %s - %s",
                                       DoubleToString(g_sessionPOC, _Digits),
                                       DoubleToString(dailyLow, _Digits),
                                       DoubleToString(dailyHigh, _Digits));
   g_analystSections[7].textColor = g_TextColor;

   //--- Section 8: SETUP + ADVISOR SUMMARY (6-factor scoring)
   double rangeSize = dailyHigh - dailyLow;
   double rangePos  = (rangeSize > 0) ? (currentPrice - dailyLow) / rangeSize * 100.0 : 50.0;

   string setupText = "";
   if(rangePos > 70)
      setupText = "CAUTION: Price near daily high. Watch for rejection or breakout.";
   else if(rangePos < 30)
      setupText = "CAUTION: Price near daily low. Watch for support or breakdown.";
   else
      setupText = "NEUTRAL: Price in middle of range.";

   int bullFactors = 0, bearFactors = 0;

   if(g_analystSections[1].textColor == g_BullishTextColor) bullFactors++;
   else if(g_analystSections[1].textColor == g_BearishTextColor) bearFactors++;

   if(h4Close > h4MA21) bullFactors++; else bearFactors++;

   if(g_analystSections[4].textColor == g_BullishTextColor) bullFactors++;
   else if(g_analystSections[4].textColor == g_BearishTextColor) bearFactors++;

   if(g_analystSections[5].textColor == g_BullishTextColor) bullFactors++;
   else if(g_analystSections[5].textColor == g_BearishTextColor) bearFactors++;

   if(g_analystSections[2].textColor == g_BullishTextColor) bullFactors++;
   else if(g_analystSections[2].textColor == g_BearishTextColor) bearFactors++;

   if(g_analystSections[3].textColor == g_BullishTextColor) bullFactors++;
   else if(g_analystSections[3].textColor == g_BearishTextColor) bearFactors++;

   string biasLabel = "";
   color  setupColor = g_NeutralTextColor;

   if(bullFactors >= 4)
   {
      biasLabel  = StringFormat("BULLISH BIAS (%d/6 factors). Consider long positions.", bullFactors);
      setupColor = g_BullishTextColor;
   }
   else if(bearFactors >= 4)
   {
      biasLabel  = StringFormat("BEARISH BIAS (%d/6 factors). Consider short positions.", bearFactors);
      setupColor = g_BearishTextColor;
   }
   else
   {
      biasLabel = StringFormat("MIXED SIGNALS (%d bull, %d bear). Wait for alignment.", bullFactors, bearFactors);
   }

   g_analystSections[8].title     = "SETUP + ADVISOR SUMMARY";
   g_analystSections[8].content   = setupText + " " + biasLabel;
   g_analystSections[8].textColor = setupColor;
}

#endif // SIGNAL_MQH
