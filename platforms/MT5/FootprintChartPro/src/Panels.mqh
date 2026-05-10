//+------------------------------------------------------------------+
//| Panels.mqh — FootprintChartPro                                    |
//| All panel rendering functions (11 panels)                         |
//+------------------------------------------------------------------+
#ifndef PANELS_MQH
#define PANELS_MQH

#include "Config.mqh"
#include "Market.mqh"
#include "Signal.mqh"
#include "Render.mqh"

//+------------------------------------------------------------------+
//| 1. DELTA CELLS FOOTPRINT (Main Panel)                             |
//+------------------------------------------------------------------+
void RenderDeltaCellsFootprint()
{
   int px = Input_MainPanelX;
   int py = Input_MainPanelY;
   int pw = Input_MainPanelWidth;
   int ph = Input_MainPanelHeight;

   DrawPanelFrame(px, py, pw, ph, "DELTA CELLS FOOTPRINT");

   int visibleBars = MathMin(Input_VisibleBars, g_fpBarCount);
   if(visibleBars == 0) return;

   int chartX = px + 60;          // Left margin for price axis
   int chartY = py + 35;          // Top margin below header
   int chartW = pw - 80;          // Chart area width
   int chartH = ph - 80;          // Chart area height

   int totalBarWidth = Input_BarWidth + Input_BarSpacing;
   int startBarIdx   = g_fpBarCount - visibleBars;

   // Find price range across visible bars
   double highPrice = -DBL_MAX;
   double lowPrice  = DBL_MAX;

   for(int b = startBarIdx; b < g_fpBarCount; b++)
   {
      if(b < 0) continue;
      if(g_fpBars[b].high > highPrice) highPrice = g_fpBars[b].high;
      if(g_fpBars[b].low  < lowPrice)  lowPrice  = g_fpBars[b].low;
   }

   double priceRange = highPrice - lowPrice;
   if(priceRange <= 0) priceRange = _Point * 100;

   // Add padding
   double padding = priceRange * 0.05;
   highPrice += padding;
   lowPrice  -= padding;
   priceRange = highPrice - lowPrice;

   // Draw price axis
   DrawPriceAxis(px, chartY, chartH, highPrice, lowPrice);

   // Draw POC / VAH / VAL lines
   if(g_sessionPOC > lowPrice && g_sessionPOC < highPrice)
   {
      int pocY = chartY + (int)((highPrice - g_sessionPOC) / priceRange * chartH);
      DrawLine(chartX, pocY, chartX + chartW, pocY, g_POCLineColor, 180);
      DrawText(px + 5, pocY - 6, "POC", Input_MonospaceFont, Input_SmallFontSize, g_POCLineColor);
   }
   if(g_sessionVAH > lowPrice && g_sessionVAH < highPrice)
   {
      int vahY = chartY + (int)((highPrice - g_sessionVAH) / priceRange * chartH);
      DrawLine(chartX, vahY, chartX + chartW, vahY, g_VAHLineColor, 100);
   }
   if(g_sessionVAL > lowPrice && g_sessionVAL < highPrice)
   {
      int valY = chartY + (int)((highPrice - g_sessionVAL) / priceRange * chartH);
      DrawLine(chartX, valY, chartX + chartW, valY, g_VALLineColor, 100);
   }

   // Render each bar
   for(int b = 0; b < visibleBars; b++)
   {
      int barIdx = startBarIdx + b;
      if(barIdx < 0 || barIdx >= g_fpBarCount) continue;

      int barX = chartX + b * totalBarWidth;
      RenderSingleBar(barX, chartY, chartH, highPrice, lowPrice, priceRange, g_fpBars[barIdx]);
   }

   // Cumulative delta line at bottom
   RenderCumulativeDeltaLine(chartX, chartY + chartH + 5, chartW, 30, startBarIdx, visibleBars);
}

//+------------------------------------------------------------------+
//| Render a single footprint bar with delta cells                    |
//+------------------------------------------------------------------+
void RenderSingleBar(int barX, int chartY, int chartH,
                     double highPrice, double lowPrice, double priceRange,
                     FootprintBar &bar)
{
   int barW = Input_BarWidth;

   // Draw candle body
   int openY  = chartY + (int)((highPrice - bar.open)  / priceRange * chartH);
   int closeY = chartY + (int)((highPrice - bar.close) / priceRange * chartH);
   int highY  = chartY + (int)((highPrice - bar.high)  / priceRange * chartH);
   int lowY   = chartY + (int)((highPrice - bar.low)   / priceRange * chartH);

   bool isBull = (bar.close >= bar.open);
   color candleColor = isBull ? g_BullCandleColor : g_BearCandleColor;

   // Wick
   int wickX = barX + barW / 2;
   DrawLine(wickX, highY, wickX, lowY, candleColor, 120);

   // Body (thin behind cells)
   int bodyTop = MathMin(openY, closeY);
   int bodyBot = MathMax(openY, closeY);
   int bodyH   = MathMax(1, bodyBot - bodyTop);
   FillRect(wickX - 2, bodyTop, 4, bodyH, candleColor, 80);

   // Render delta cells for each price level
   for(int i = 0; i < bar.levelCount; i++)
   {
      double lvlPrice = bar.levels[i].price;
      if(lvlPrice < lowPrice || lvlPrice > highPrice) continue;

      int cellY = chartY + (int)((highPrice - lvlPrice) / priceRange * chartH);
      int cellH = Input_CellHeight;

      // Ensure cell fits
      if(cellY < chartY || cellY + cellH > chartY + chartH) continue;

      long buyVol  = bar.levels[i].buyVolume;
      long sellVol = bar.levels[i].sellVolume;
      long delta   = bar.levels[i].delta;

      // Cell background color (6-level intensity)
      color bgColor = GetIntensityColor(buyVol, sellVol);

      // POC highlight
      bool isPOC = (i == bar.pocIndex && bar.levelCount > 0);
      if(isPOC)
         bgColor = g_POCLineColor;

      // Draw cell background
      FillRect(barX, cellY, barW, cellH - Input_CellGap, bgColor, 200);

      // Imbalance border
      if(bar.levels[i].imbalanceLevel > 0)
      {
         color borderClr = GetImbalanceBorderColor(bar.levels[i].imbalanceLevel,
                                                    bar.levels[i].isBuyImbalance);
         DrawRect(barX, cellY, barW, cellH - Input_CellGap, borderClr);
         DrawRect(barX + 1, cellY + 1, barW - 2, cellH - Input_CellGap - 2, borderClr);
      }

      // Delta text
      int fontSize = Input_SmallFontSize;
      if(bar.levels[i].imbalanceLevel >= 2)
         fontSize += Input_ImbalanceTier2SizeBoost;
      else if(bar.levels[i].imbalanceLevel >= 3)
         fontSize += Input_ImbalanceTier3SizeBoost;

      color textColor = (delta > 0) ? g_BuyTextColor : ((delta < 0) ? g_SellTextColor : g_TextColor);
      string deltaStr = (delta > 0) ? "+" + IntegerToString(delta) : IntegerToString(delta);

      // Buy x Sell format inside cell
      string cellText = IntegerToString(buyVol) + "x" + IntegerToString(sellVol);

      // Draw buy x sell text
      DrawTextCentered(barX + barW / 2, cellY + (cellH - Input_CellGap) / 2 - 4,
                       cellText, Input_MonospaceFont, fontSize, textColor);

      // Draw delta below buy x sell
      if(cellH >= 20)
      {
         color dColor = (delta > 0) ? g_BuyTextColor : ((delta < 0) ? g_SellTextColor : g_NeutralTextColor);
         DrawTextCentered(barX + barW / 2, cellY + (cellH - Input_CellGap) / 2 + 6,
                          deltaStr, Input_MonospaceFont, Input_SmallFontSize - 1, dColor);
      }
   }

   // Bar delta total below bar
   string barDeltaStr = (bar.totalDelta >= 0) ? "+" + IntegerToString(bar.totalDelta) : IntegerToString(bar.totalDelta);
   color  barDeltaClr = (bar.totalDelta > 0) ? g_BuyTextColor : ((bar.totalDelta < 0) ? g_SellTextColor : g_TextColor);
   DrawTextCentered(barX + barW / 2, chartY + chartH + 2, barDeltaStr,
                    Input_MonospaceFont, Input_SmallFontSize, barDeltaClr);

   // Time label
   string timeStr = TimeToString(bar.time, TIME_MINUTES);
   DrawTextCentered(barX + barW / 2, chartY + chartH + 14, timeStr,
                    Input_MonospaceFont, Input_SmallFontSize - 1, g_TextColor);
}

//+------------------------------------------------------------------+
//| Draw price axis on left side                                      |
//+------------------------------------------------------------------+
void DrawPriceAxis(int x, int chartY, int chartH, double highPrice, double lowPrice)
{
   double priceRange = highPrice - lowPrice;
   int levels = 8;
   for(int i = 0; i <= levels; i++)
   {
      double price = highPrice - (priceRange * i / levels);
      int y = chartY + (chartH * i / levels);
      string priceStr = DoubleToString(price, _Digits);
      DrawTextRight(x + 55, y - 5, priceStr, Input_MonospaceFont, Input_SmallFontSize - 1, g_TextColor);
   }
}

//+------------------------------------------------------------------+
//| Render cumulative delta line at bottom of footprint               |
//+------------------------------------------------------------------+
void RenderCumulativeDeltaLine(int x, int y, int w, int h, int startIdx, int count)
{
   if(count < 2) return;

   // Find cumDelta range
   long maxCD = LONG_MIN, minCD = LONG_MAX;
   for(int i = 0; i < count; i++)
   {
      int idx = startIdx + i;
      if(idx < 0 || idx >= g_fpBarCount) continue;
      if(g_fpBars[idx].cumulativeDelta > maxCD) maxCD = g_fpBars[idx].cumulativeDelta;
      if(g_fpBars[idx].cumulativeDelta < minCD) minCD = g_fpBars[idx].cumulativeDelta;
   }

   long cdRange = maxCD - minCD;
   if(cdRange == 0) cdRange = 1;

   int totalBarWidth = Input_BarWidth + Input_BarSpacing;

   // Draw background
   FillRect(x, y, w, h, C'25,25,25');

   // Draw zero line
   if(minCD < 0 && maxCD > 0)
   {
      int zeroY = y + (int)((double)maxCD / cdRange * h);
      DrawLine(x, zeroY, x + w, zeroY, g_TextColor, 60);
   }

   // Draw cumulative delta line
   for(int i = 0; i < count - 1; i++)
   {
      int idx1 = startIdx + i;
      int idx2 = startIdx + i + 1;
      if(idx1 < 0 || idx2 >= g_fpBarCount) continue;

      int x1 = x + i * totalBarWidth + Input_BarWidth / 2;
      int x2 = x + (i + 1) * totalBarWidth + Input_BarWidth / 2;

      int y1 = y + (int)((double)(maxCD - g_fpBars[idx1].cumulativeDelta) / cdRange * h);
      int y2 = y + (int)((double)(maxCD - g_fpBars[idx2].cumulativeDelta) / cdRange * h);

      color lineClr = (g_fpBars[idx2].cumulativeDelta >= g_fpBars[idx1].cumulativeDelta)
                     ? g_BuyTextColor : g_SellTextColor;
      DrawLine(x1, y1, x2, y2, lineClr);
   }

   // Label
   DrawText(x + 2, y + 1, "CumDelta", Input_MonospaceFont, Input_SmallFontSize - 1, g_TextColor);
}

//+------------------------------------------------------------------+
//| 2. SUMMARY TABLE (below footprint)                                |
//+------------------------------------------------------------------+
void RenderSummaryTable()
{
   int px = Input_MainPanelX;
   int py = Input_MainPanelY + Input_MainPanelHeight + 5;
   int pw = Input_MainPanelWidth;
   int ph = 60;

   DrawPanelFrame(px, py, pw, ph, "SUMMARY");

   if(g_fpBarCount == 0) return;

   int curIdx = g_fpBarCount - 1;
   long totalBuy = 0, totalSell = 0;
   for(int i = 0; i < g_fpBars[curIdx].levelCount; i++)
   {
      totalBuy  += g_fpBars[curIdx].levels[i].buyVolume;
      totalSell += g_fpBars[curIdx].levels[i].sellVolume;
   }

   int col = px + 10;
   int row = py + 32;

   DrawText(col, row, "Vol: " + IntegerToString(g_fpBars[curIdx].totalVolume),
            Input_MonospaceFont, Input_SmallFontSize, g_TextColor);

   col += 120;
   DrawText(col, row, "Buy: " + IntegerToString(totalBuy),
            Input_MonospaceFont, Input_SmallFontSize, g_BuyTextColor);

   col += 120;
   DrawText(col, row, "Sell: " + IntegerToString(totalSell),
            Input_MonospaceFont, Input_SmallFontSize, g_SellTextColor);

   col += 120;
   string deltaStr = (g_fpBars[curIdx].totalDelta >= 0) ? "+" : "";
   deltaStr += IntegerToString(g_fpBars[curIdx].totalDelta);
   color dClr = (g_fpBars[curIdx].totalDelta > 0) ? g_BuyTextColor : g_SellTextColor;
   DrawText(col, row, "Delta: " + deltaStr, Input_MonospaceFont, Input_SmallFontSize, dClr);

   col += 140;
   DrawText(col, row, "POC: " + DoubleToString(g_fpBars[curIdx].poc, _Digits),
            Input_MonospaceFont, Input_SmallFontSize, g_POCLineColor);

   col += 160;
   string cdStr = (g_fpBars[curIdx].cumulativeDelta >= 0) ? "+" : "";
   cdStr += IntegerToString(g_fpBars[curIdx].cumulativeDelta);
   DrawText(col, row, "CumD: " + cdStr, Input_MonospaceFont, Input_SmallFontSize,
            (g_fpBars[curIdx].cumulativeDelta > 0) ? g_BuyTextColor : g_SellTextColor);
}

//+------------------------------------------------------------------+
//| 3. DOM PANEL                                                      |
//+------------------------------------------------------------------+
void RenderDOMPanel()
{
   int px = Input_MainPanelX + Input_MainPanelWidth + 10;
   int py = Input_MainPanelY;
   int pw = Input_DOMPanelWidth;
   int ph = Input_DOMPanelHeight;

   DrawPanelFrame(px, py, pw, ph, "DEPTH OF MARKET");

   if(g_domLevelCount == 0)
   {
      DrawTextCentered(px + pw / 2, py + ph / 2, "No DOM data",
                       Input_PrimaryFont, Input_SmallFontSize, g_TextColor);
      return;
   }

   // Column headers
   int hdrY = py + 32;
   DrawText(px + 10, hdrY, "Bid",  Input_MonospaceFont, Input_SmallFontSize, g_BuyTextColor);
   DrawText(px + 80, hdrY, "Price", Input_MonospaceFont, Input_SmallFontSize, g_TextColor);
   DrawText(px + 180, hdrY, "Ask",  Input_MonospaceFont, Input_SmallFontSize, g_SellTextColor);

   int rowH = 22;
   int visibleLevels = MathMin(Input_DOMVisibleLevels, g_domLevelCount);

   // Find max volume for scaling bar widths
   long maxVol = 1;
   for(int i = 0; i < visibleLevels; i++)
   {
      if(g_domLevels[i].bidOrders > maxVol) maxVol = g_domLevels[i].bidOrders;
      if(g_domLevels[i].askOrders > maxVol) maxVol = g_domLevels[i].askOrders;
   }

   int currentY = hdrY + 22;
   int barMaxW  = 60;

   for(int i = 0; i < visibleLevels; i++)
   {
      // Gridlines
      if(Input_ShowDOMGridlines)
         DrawLine(px + 5, currentY + rowH - 1, px + pw - 5, currentY + rowH - 1, g_TextColor, 30);

      // Bid bar + text
      if(g_domLevels[i].bidOrders > 0)
      {
         int barW = (int)((double)g_domLevels[i].bidOrders / maxVol * barMaxW);
         FillRect(px + 70 - barW, currentY + 2, barW, rowH - 4, g_BullCandleColor, 150);

         // Flash highlight
         if(g_domLevels[i].flashBuy)
            DrawRect(px + 70 - barW, currentY + 2, barW, rowH - 4, clrYellow);

         DrawTextRight(px + 68, currentY + 3, IntegerToString(g_domLevels[i].bidOrders),
                       Input_MonospaceFont, Input_SmallFontSize, g_BuyTextColor);
      }

      // Price
      DrawTextCentered(px + 130, currentY + rowH / 2,
                       DoubleToString(g_domLevels[i].price, _Digits),
                       Input_MonospaceFont, Input_SmallFontSize, g_TextColor);

      // Ask bar + text
      if(g_domLevels[i].askOrders > 0)
      {
         int barW = (int)((double)g_domLevels[i].askOrders / maxVol * barMaxW);
         FillRect(px + 190, currentY + 2, barW, rowH - 4, g_BearCandleColor, 150);

         if(g_domLevels[i].flashSell)
            DrawRect(px + 190, currentY + 2, barW, rowH - 4, clrYellow);

         DrawText(px + 192, currentY + 3, IntegerToString(g_domLevels[i].askOrders),
                  Input_MonospaceFont, Input_SmallFontSize, g_SellTextColor);
      }

      currentY += rowH;
   }
}

//+------------------------------------------------------------------+
//| 4. SESSION VOLUME PROFILE PANEL                                   |
//+------------------------------------------------------------------+
void RenderVolumeProfilePanel()
{
   int px = Input_MainPanelX + Input_MainPanelWidth + Input_DOMPanelWidth + 20;
   int py = Input_MainPanelY;
   int pw = Input_VPPanelWidth;
   int ph = Input_VPPanelHeight;

   DrawPanelFrame(px, py, pw, ph, "VOLUME PROFILE");

   if(g_vpLevelCount == 0)
   {
      DrawTextCentered(px + pw / 2, py + ph / 2, "No data",
                       Input_PrimaryFont, Input_SmallFontSize, g_TextColor);
      return;
   }

   // Find price range and max volume
   double vpHigh = -DBL_MAX, vpLow = DBL_MAX;
   long vpMaxVol = 0;
   for(int i = 0; i < g_vpLevelCount; i++)
   {
      if(g_vpLevels[i].price > vpHigh) vpHigh = g_vpLevels[i].price;
      if(g_vpLevels[i].price < vpLow)  vpLow  = g_vpLevels[i].price;

      long dispVol = GetVPDisplayVolume(g_vpLevels[i]);
      if(dispVol > vpMaxVol) vpMaxVol = dispVol;
   }

   double vpRange = vpHigh - vpLow;
   if(vpRange <= 0) vpRange = _Point;
   if(vpMaxVol == 0) vpMaxVol = 1;

   int chartY = py + 35;
   int chartH = ph - 80;
   int barMaxW = pw - 30;

   for(int i = 0; i < g_vpLevelCount; i++)
   {
      int barY = chartY + (int)((vpHigh - g_vpLevels[i].price) / vpRange * chartH);
      int barH = MathMax(3, chartH / g_vpLevelCount - 1);

      long dispVol = GetVPDisplayVolume(g_vpLevels[i]);
      int barW = (int)((double)dispVol / vpMaxVol * barMaxW * Input_VPBarWidthScale);

      color barColor = GetVPBarColor(g_vpLevels[i]);
      FillRect(px + 15, barY, barW, barH, barColor, 180);

      // POC highlight
      if(MathAbs(g_vpLevels[i].price - g_sessionPOC) < _Point * 0.5)
         DrawRect(px + 15, barY, barW, barH, g_POCLineColor);
   }

   // Legends
   int legendY = py + ph - 40;
   DrawText(px + 5, legendY, "POC: " + DoubleToString(g_sessionPOC, _Digits),
            Input_MonospaceFont, Input_SmallFontSize, g_POCLineColor);
   DrawText(px + 5, legendY + 12, "VAH: " + DoubleToString(g_sessionVAH, _Digits),
            Input_MonospaceFont, Input_SmallFontSize, g_VAHLineColor);
   DrawText(px + 5, legendY + 24, "VAL: " + DoubleToString(g_sessionVAL, _Digits),
            Input_MonospaceFont, Input_SmallFontSize, g_VALLineColor);
}

//+------------------------------------------------------------------+
//| Get volume to display based on display type setting               |
//+------------------------------------------------------------------+
long GetVPDisplayVolume(VolumeProfileLevel &level)
{
   switch(Input_VPDisplayType)
   {
      case VP_DISPLAY_DELTA: return MathAbs(level.delta);
      case VP_DISPLAY_BUY:   return level.buyVolume;
      case VP_DISPLAY_SELL:  return level.sellVolume;
      default:               return level.totalVolume;
   }
}

//+------------------------------------------------------------------+
//| Get color for VP bar based on display type                        |
//+------------------------------------------------------------------+
color GetVPBarColor(VolumeProfileLevel &level)
{
   switch(Input_VPDisplayType)
   {
      case VP_DISPLAY_DELTA:
         return (level.delta > 0) ? g_VPDeltaBuyColor : g_VPDeltaSellColor;
      case VP_DISPLAY_BUY:   return g_VPBuyVolumeColor;
      case VP_DISPLAY_SELL:  return g_VPSellVolumeColor;
      default:               return g_VPTotalVolumeColor;
   }
}

//+------------------------------------------------------------------+
//| 5. TIME & SALES PANEL                                             |
//+------------------------------------------------------------------+
void RenderTimeAndSalesPanel()
{
   int px = Input_MainPanelX + Input_MainPanelWidth + 10;
   int py = Input_MainPanelY + Input_DOMPanelHeight + 10;
   int pw = Input_TSPanelWidth;
   int ph = Input_TSPanelHeight;

   DrawPanelFrame(px, py, pw, ph, "TIME & SALES");

   // Column headers
   int hdrY = py + 32;
   DrawText(px + 8,   hdrY, "Time",   Input_MonospaceFont, Input_SmallFontSize, g_TextColor);
   DrawText(px + 75,  hdrY, "Price",  Input_MonospaceFont, Input_SmallFontSize, g_TextColor);
   DrawText(px + 155, hdrY, "Vol",    Input_MonospaceFont, Input_SmallFontSize, g_TextColor);
   DrawText(px + 210, hdrY, "Side",   Input_MonospaceFont, Input_SmallFontSize, g_TextColor);

   int rowH = 20;
   int visibleRows = Input_TSVisibleRows;
   int startIdx = MathMax(0, g_tsTickCount - visibleRows);
   int currentY = hdrY + 22;

   for(int i = startIdx; i < g_tsTickCount; i++)
   {
      // Big order highlight
      if(g_tsTicks[i].isBigOrder)
         FillRect(px + 2, currentY, pw - 4, rowH, g_BigOrderHighlightColor, 150);

      color textClr = g_TextColor;
      if(g_tsTicks[i].direction == 1)       textClr = g_BuyTextColor;
      else if(g_tsTicks[i].direction == -1) textClr = g_SellTextColor;

      DrawText(px + 8,   currentY + 2, TimeToString(g_tsTicks[i].time, TIME_SECONDS),
               Input_MonospaceFont, Input_SmallFontSize, textClr);
      DrawText(px + 75,  currentY + 2, DoubleToString(g_tsTicks[i].price, _Digits),
               Input_MonospaceFont, Input_SmallFontSize, textClr);
      DrawText(px + 155, currentY + 2, IntegerToString(g_tsTicks[i].volume),
               Input_MonospaceFont, Input_SmallFontSize, textClr);

      string sideStr = (g_tsTicks[i].direction == 1) ? "BUY" :
                       (g_tsTicks[i].direction == -1) ? "SELL" : "---";
      DrawText(px + 210, currentY + 2, sideStr,
               Input_MonospaceFont, Input_SmallFontSize, textClr);

      currentY += rowH;
   }

   // Bar totals
   CalculateTSBarTotals();
   int totY = py + ph - 45;
   DrawText(px + 8, totY, "Bar Totals:", Input_PrimaryFont, Input_SmallFontSize, g_TextColor);
   DrawText(px + 90, totY, "Buy: " + IntegerToString(g_tsBarBuyVolume),
            Input_MonospaceFont, Input_SmallFontSize, g_BuyTextColor);
   DrawText(px + 190, totY, "Sell: " + IntegerToString(g_tsBarSellVolume),
            Input_MonospaceFont, Input_SmallFontSize, g_SellTextColor);

   double buyRatio = (g_tsBarBuyVolume + g_tsBarSellVolume > 0)
                   ? (double)g_tsBarBuyVolume / (g_tsBarBuyVolume + g_tsBarSellVolume) * 100.0
                   : 50.0;
   DrawText(px + 8, totY + 16, "B/S Ratio: " + DoubleToString(buyRatio, 1) + "%",
            Input_MonospaceFont, Input_SmallFontSize, g_TextColor);
}

//+------------------------------------------------------------------+
//| 6. SIGNAL METER GAUGE                                             |
//+------------------------------------------------------------------+
void RenderSignalMeterGauge()
{
   int px = Input_MainPanelX + Input_MainPanelWidth + Input_DOMPanelWidth + Input_VPPanelWidth + 30;
   int py = Input_MainPanelY;
   int pw = 250;
   int ph = 250;

   DrawPanelFrame(px, py, pw, ph, "SIGNAL METER");

   int centerX = px + pw / 2;
   int centerY = py + ph / 2 + 20;
   int radius  = 80;

   // Colored arc zones (semi-circle: 180° to 0° = left to right)
   DrawArc(centerX, centerY, radius, 120, 156, g_StrongSellColor, 8);
   DrawArc(centerX, centerY, radius,  84, 120, g_SellColor, 8);
   DrawArc(centerX, centerY, radius,  60,  84, g_NeutralGaugeColor, 8);
   DrawArc(centerX, centerY, radius,  24,  60, g_BuyColor, 8);
   DrawArc(centerX, centerY, radius,   0,  24, g_StrongBuyColor, 8);

   // Calculate and draw pointer
   double signalVal = CalculateSignalMeterValue();
   // Map -100..+100 to 156°..24° (left=sell, right=buy)
   double angle = 90.0 - (signalVal / 100.0) * 66.0;
   DrawPointer(centerX, centerY, radius - 15, angle, g_PointerColor, 3);

   // Labels
   DrawText(px + 10, centerY + radius - 5, "STRONG SELL",
            Input_PrimaryFont, Input_SmallFontSize - 1, g_StrongSellColor);
   DrawText(px + pw - 85, centerY + radius - 5, "STRONG BUY",
            Input_PrimaryFont, Input_SmallFontSize - 1, g_StrongBuyColor);

   // Value
   DrawTextCentered(centerX, centerY + 30, DoubleToString(signalVal, 1),
                    Input_MonospaceFont, Input_LargeFontSize, g_TextColor);
}

//+------------------------------------------------------------------+
//| 7. CHART ANALYST PANEL                                            |
//+------------------------------------------------------------------+
void RenderChartAnalystPanel()
{
   int px = Input_MainPanelX + Input_MainPanelWidth + Input_TSPanelWidth + 20;
   int py = Input_MainPanelY + Input_DOMPanelHeight + 10;
   int pw = Input_AnalystPanelWidth;
   int ph = Input_AnalystPanelHeight;

   DrawPanelFrame(px, py, pw, ph, "CHART ANALYST");

   // Update time
   int secAgo = (int)(TimeCurrent() - g_lastAnalystUpdate);
   DrawTextRight(px + pw - 10, py + 8, "Updated: " + IntegerToString(secAgo) + "s ago",
                 Input_PrimaryFont, Input_SmallFontSize - 1, g_TextColor);

   int currentY = py + 38;
   int sectionSpacing = 10;

   for(int i = 0; i < 9; i++)
   {
      // Section title
      DrawText(px + 8, currentY, g_analystSections[i].title,
               Input_PrimaryFont, Input_BaseFontSize, g_HeaderTextColor);
      currentY += 16;

      // Section content (word wrapped)
      int textH = DrawTextWordWrap(px + 15, currentY, pw - 30, g_analystSections[i].content,
                                   Input_PrimaryFont, Input_SmallFontSize, g_analystSections[i].textColor);
      currentY += textH + sectionSpacing;

      // Don't overflow panel
      if(currentY > py + ph - 20) break;
   }
}

//+------------------------------------------------------------------+
//| 8. RSI PANEL                                                      |
//+------------------------------------------------------------------+
void RenderRSIPanel()
{
   int px = Input_MainPanelX + Input_MainPanelWidth + Input_DOMPanelWidth + Input_VPPanelWidth + 30;
   int py = Input_MainPanelY + 260;
   int pw = Input_IndicatorPanelWidth;
   int ph = Input_IndicatorPanelHeight;

   DrawPanelFrame(px, py, pw, ph, "RSI(14)");

   // Get RSI values
   double rsiVals[];
   int count = 50;
   if(GetIndicatorValues(g_hRSI, 0, 0, count, rsiVals) != count) return;

   int chartX = px + 30;
   int chartY = py + 35;
   int chartW = pw - 40;
   int chartH = ph - 55;

   // OB/OS lines
   int obY = chartY + (int)((100.0 - Input_RSIOverbought) / 100.0 * chartH);
   int osY = chartY + (int)((100.0 - Input_RSIOversold) / 100.0 * chartH);

   DrawLine(chartX, obY, chartX + chartW, obY, g_OverboughtLineColor, 100);
   DrawLine(chartX, osY, chartX + chartW, osY, g_OversoldLineColor, 100);

   DrawText(px + 5, obY - 5, IntegerToString(Input_RSIOverbought),
            Input_MonospaceFont, Input_SmallFontSize - 1, g_OverboughtLineColor);
   DrawText(px + 5, osY - 5, IntegerToString(Input_RSIOversold),
            Input_MonospaceFont, Input_SmallFontSize - 1, g_OversoldLineColor);

   // RSI line (data is newest first, draw left to right = oldest to newest)
   int barW = chartW / count;
   for(int i = 0; i < count - 1; i++)
   {
      int dataIdx1 = count - 1 - i;
      int dataIdx2 = count - 2 - i;

      int x1 = chartX + i * barW;
      int x2 = chartX + (i + 1) * barW;
      int y1 = chartY + (int)((100.0 - rsiVals[dataIdx1]) / 100.0 * chartH);
      int y2 = chartY + (int)((100.0 - rsiVals[dataIdx2]) / 100.0 * chartH);

      DrawLine(x1, y1, x2, y2, g_RSILineColor);
   }

   // Current value
   DrawTextRight(px + pw - 8, py + 8, DoubleToString(rsiVals[0], 1),
                 Input_MonospaceFont, Input_BaseFontSize, g_RSILineColor);
}

//+------------------------------------------------------------------+
//| 9. MACD PANEL                                                     |
//+------------------------------------------------------------------+
void RenderMACDPanel()
{
   int px = Input_MainPanelX + Input_MainPanelWidth + Input_DOMPanelWidth + Input_VPPanelWidth + 30;
   int py = Input_MainPanelY + 260 + Input_IndicatorPanelHeight + 10;
   int pw = Input_IndicatorPanelWidth;
   int ph = Input_IndicatorPanelHeight;

   DrawPanelFrame(px, py, pw, ph, "MACD");

   double macdMain[], macdSignal[];
   int count = 50;
   if(GetIndicatorValues(g_hMACD, 0, 0, count, macdMain) != count) return;
   if(GetIndicatorValues(g_hMACD, 1, 0, count, macdSignal) != count) return;

   // Calculate histogram
   double histogram[];
   ArrayResize(histogram, count);
   double maxH = 0;
   for(int i = 0; i < count; i++)
   {
      histogram[i] = macdMain[i] - macdSignal[i];
      if(MathAbs(histogram[i]) > maxH) maxH = MathAbs(histogram[i]);
   }
   if(maxH == 0) maxH = 1;

   int chartX = px + 30;
   int chartY = py + 35;
   int chartW = pw - 40;
   int chartH = ph - 50;
   int zeroY  = chartY + chartH / 2;

   DrawLine(chartX, zeroY, chartX + chartW, zeroY, g_TextColor, 60);

   int barW = chartW / count;
   for(int i = 0; i < count; i++)
   {
      int dataIdx = count - 1 - i;
      int x = chartX + i * barW;
      int barH = (int)(histogram[dataIdx] / maxH * (chartH / 2 - 5));

      color barClr = (histogram[dataIdx] > 0) ? g_MACDBullColor : g_MACDBearColor;

      if(barH > 0)
         FillRect(x, zeroY - barH, barW - 1, barH, barClr, 200);
      else
         FillRect(x, zeroY, barW - 1, -barH, barClr, 200);
   }

   // Current value
   DrawTextRight(px + pw - 8, py + 8, DoubleToString(histogram[0], _Digits + 1),
                 Input_MonospaceFont, Input_BaseFontSize,
                 (histogram[0] > 0) ? g_MACDBullColor : g_MACDBearColor);
}

//+------------------------------------------------------------------+
//| 10. SUPPLY & DEMAND ZONES OVERLAY                                 |
//| Rendered on top of the main footprint panel                       |
//+------------------------------------------------------------------+
void RenderSupplyDemandZones()
{
   if(g_zoneCount == 0) return;

   int chartX = Input_MainPanelX + 60;
   int chartY = Input_MainPanelY + 35;
   int chartW = Input_MainPanelWidth - 80;
   int chartH = Input_MainPanelHeight - 80;

   // Need price range from visible bars
   int visibleBars = MathMin(Input_VisibleBars, g_fpBarCount);
   int startBarIdx = g_fpBarCount - visibleBars;

   double highPrice = -DBL_MAX, lowPrice = DBL_MAX;
   for(int b = startBarIdx; b < g_fpBarCount; b++)
   {
      if(b < 0) continue;
      if(g_fpBars[b].high > highPrice) highPrice = g_fpBars[b].high;
      if(g_fpBars[b].low  < lowPrice)  lowPrice  = g_fpBars[b].low;
   }

   double padding = (highPrice - lowPrice) * 0.05;
   highPrice += padding;
   lowPrice  -= padding;
   double priceRange = highPrice - lowPrice;
   if(priceRange <= 0) return;

   for(int i = 0; i < g_zoneCount; i++)
   {
      if(!g_zones[i].isActive) continue;
      if(g_zones[i].bottomPrice > highPrice || g_zones[i].topPrice < lowPrice) continue;

      int y1 = chartY + (int)((highPrice - g_zones[i].topPrice)    / priceRange * chartH);
      int y2 = chartY + (int)((highPrice - g_zones[i].bottomPrice) / priceRange * chartH);

      y1 = MathMax(y1, chartY);
      y2 = MathMin(y2, chartY + chartH);

      color zClr = g_zones[i].isSupply ? g_SupplyZoneColor : g_DemandZoneColor;
      uchar alpha = (uchar)Input_ZoneOpacity;

      FillRect(chartX, y1, chartW, y2 - y1, zClr, alpha);
      DrawRect(chartX, y1, chartW, y2 - y1, zClr, (uchar)MathMin(255, alpha + 80));
   }
}

//+------------------------------------------------------------------+
//| 11. ECONOMIC CALENDAR PANEL                                       |
//+------------------------------------------------------------------+
void RenderEconomicCalendarPanel()
{
   int px = Input_MainPanelX;
   int py = Input_MainPanelY + Input_MainPanelHeight + 70;
   int pw = Input_CalendarPanelWidth;
   int ph = Input_CalendarPanelHeight;

   DrawPanelFrame(px, py, pw, ph, "ECONOMIC CALENDAR");

   // Column headers
   int hdrY = py + 32;
   DrawText(px + 8,   hdrY, "Time",     Input_MonospaceFont, Input_SmallFontSize, g_TextColor);
   DrawText(px + 100, hdrY, "Event",    Input_PrimaryFont,   Input_SmallFontSize, g_TextColor);
   DrawText(px + 270, hdrY, "Ccy",      Input_MonospaceFont, Input_SmallFontSize, g_TextColor);
   DrawText(px + 330, hdrY, "Imp",      Input_MonospaceFont, Input_SmallFontSize, g_TextColor);

   int rowH = 22;
   int currentY = hdrY + 20;
   int maxRows = MathMin(Input_CalendarMaxRows, g_calendarCount);

   for(int i = 0; i < maxRows; i++)
   {
      DrawText(px + 8, currentY, TimeToString(g_calendarEvents[i].eventTime, TIME_DATE | TIME_MINUTES),
               Input_MonospaceFont, Input_SmallFontSize, g_TextColor);

      string title = g_calendarEvents[i].eventTitle;
      if(StringLen(title) > 22) title = StringSubstr(title, 0, 19) + "...";
      DrawText(px + 100, currentY, title, Input_PrimaryFont, Input_SmallFontSize, g_TextColor);

      DrawText(px + 270, currentY, g_calendarEvents[i].currency,
               Input_MonospaceFont, Input_SmallFontSize, g_TextColor);

      color impClr = (g_calendarEvents[i].importance == 3) ? clrRed :
                     (g_calendarEvents[i].importance == 2) ? clrOrange : clrGray;
      string impStr = (g_calendarEvents[i].importance == 3) ? "HIGH" :
                      (g_calendarEvents[i].importance == 2) ? "MED" : "LOW";
      DrawText(px + 330, currentY, impStr, Input_PrimaryFont, Input_SmallFontSize, impClr);

      currentY += rowH;
   }
}

//+------------------------------------------------------------------+
//| 12. MINI SESSION CHART                                            |
//+------------------------------------------------------------------+
void RenderMiniSessionChart()
{
   int px = Input_MainPanelX + Input_CalendarPanelWidth + 10;
   int py = Input_MainPanelY + Input_MainPanelHeight + 70;
   int pw = Input_MiniChartWidth;
   int ph = Input_MiniChartHeight;

   DrawPanelFrame(px, py, pw, ph, "SESSION CHART (M1)");

   if(g_sessionCandleCount == 0)
   {
      DrawTextCentered(px + pw / 2, py + ph / 2, "No session data",
                       Input_PrimaryFont, Input_SmallFontSize, g_TextColor);
      return;
   }

   // Price range
   double high = -DBL_MAX, low = DBL_MAX;
   for(int i = 0; i < g_sessionCandleCount; i++)
   {
      if(g_sessionCandles[i].high > high) high = g_sessionCandles[i].high;
      if(g_sessionCandles[i].low  < low)  low  = g_sessionCandles[i].low;
   }

   double range = high - low;
   if(range <= 0) range = _Point;

   int chartY = py + 30;
   int chartH = ph - 40;
   int candleW = MathMax(1, (pw - 20) / g_sessionCandleCount);

   for(int i = 0; i < g_sessionCandleCount; i++)
   {
      int x = px + 10 + i * candleW;

      int openY  = chartY + (int)((high - g_sessionCandles[i].open)  / range * chartH);
      int closeY = chartY + (int)((high - g_sessionCandles[i].close) / range * chartH);
      int highY  = chartY + (int)((high - g_sessionCandles[i].high)  / range * chartH);
      int lowY   = chartY + (int)((high - g_sessionCandles[i].low)   / range * chartH);

      bool isBull = (g_sessionCandles[i].close >= g_sessionCandles[i].open);
      color cClr = isBull ? g_BullCandleColor : g_BearCandleColor;

      // Wick
      DrawLine(x + candleW / 2, highY, x + candleW / 2, lowY, cClr);

      // Body
      int bodyTop = MathMin(openY, closeY);
      int bodyH   = MathMax(1, MathAbs(closeY - openY));
      if(isBull)
         DrawRect(x, bodyTop, candleW - 1, bodyH, cClr);
      else
         FillRect(x, bodyTop, candleW - 1, bodyH, cClr);
   }
}

#endif // PANELS_MQH
