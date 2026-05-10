//+------------------------------------------------------------------+
//| Render.mqh — FootprintChartPro                                    |
//| Canvas rendering engine, drawing primitives, theme management     |
//+------------------------------------------------------------------+
#ifndef RENDER_MQH
#define RENDER_MQH

#include <Canvas\Canvas.mqh>
#include "Config.mqh"

//+------------------------------------------------------------------+
//| Global canvas object                                              |
//+------------------------------------------------------------------+
CCanvas g_canvas;

//+------------------------------------------------------------------+
//| Initialize the canvas                                             |
//+------------------------------------------------------------------+
bool InitCanvas()
{
   long chartWidth  = 0, chartHeight = 0;
   ChartGetInteger(0, CHART_WIDTH_IN_PIXELS,  0, chartWidth);
   ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chartHeight);

   int w = (int)MathMax(chartWidth,  1920);
   int h = (int)MathMax(chartHeight, 1080);

   if(!g_canvas.CreateBitmapLabel(FP_CANVAS_NAME, 0, 0, w, h, COLOR_FORMAT_ARGB_NORMALIZE))
   {
      Print("[", EA_NAME, "] Failed to create canvas. Error: ", GetLastError());
      return false;
   }

   // Bring to front
   ObjectSetInteger(0, FP_CANVAS_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, FP_CANVAS_NAME, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, FP_CANVAS_NAME, OBJPROP_HIDDEN, true);

   return true;
}

//+------------------------------------------------------------------+
//| Destroy the canvas                                                |
//+------------------------------------------------------------------+
void DestroyCanvas()
{
   g_canvas.Destroy();
}

//+------------------------------------------------------------------+
//| Clear canvas with background color                                |
//+------------------------------------------------------------------+
void ClearCanvas()
{
   g_canvas.Erase(ColorToARGB(g_PanelBackgroundColor, 255));
}

//+------------------------------------------------------------------+
//| Update (flush) canvas to screen                                   |
//+------------------------------------------------------------------+
void FlushCanvas()
{
   g_canvas.Update();
}

//+------------------------------------------------------------------+
//| Convert color to ARGB uint                                        |
//+------------------------------------------------------------------+
uint ToARGB(color clr, uchar alpha = 255)
{
   return ColorToARGB(clr, alpha);
}

//+------------------------------------------------------------------+
//| Fill a rectangle                                                  |
//+------------------------------------------------------------------+
void FillRect(int x, int y, int w, int h, color clr, uchar alpha = 255)
{
   g_canvas.FillRectangle(x, y, x + w, y + h, ToARGB(clr, alpha));
}

//+------------------------------------------------------------------+
//| Draw rectangle outline                                            |
//+------------------------------------------------------------------+
void DrawRect(int x, int y, int w, int h, color clr, uchar alpha = 255)
{
   g_canvas.Rectangle(x, y, x + w, y + h, ToARGB(clr, alpha));
}

//+------------------------------------------------------------------+
//| Draw a line                                                       |
//+------------------------------------------------------------------+
void DrawLine(int x1, int y1, int x2, int y2, color clr, uchar alpha = 255)
{
   g_canvas.Line(x1, y1, x2, y2, ToARGB(clr, alpha));
}

//+------------------------------------------------------------------+
//| Draw text at position                                             |
//+------------------------------------------------------------------+
void DrawText(int x, int y, string text, string font, int fontSize, color clr, uint flags = 0)
{
   g_canvas.FontSet(font, -fontSize * 10);
   g_canvas.TextOut(x, y, text, ToARGB(clr), flags);
}

//+------------------------------------------------------------------+
//| Draw centered text                                                |
//+------------------------------------------------------------------+
void DrawTextCentered(int x, int y, string text, string font, int fontSize, color clr)
{
   g_canvas.FontSet(font, -fontSize * 10);
   int tw = 0, th = 0;
   g_canvas.TextSize(text, tw, th);
   g_canvas.TextOut(x - tw / 2, y - th / 2, text, ToARGB(clr));
}

//+------------------------------------------------------------------+
//| Draw right-aligned text                                           |
//+------------------------------------------------------------------+
void DrawTextRight(int x, int y, string text, string font, int fontSize, color clr)
{
   g_canvas.FontSet(font, -fontSize * 10);
   int tw = 0, th = 0;
   g_canvas.TextSize(text, tw, th);
   g_canvas.TextOut(x - tw, y, text, ToARGB(clr));
}

//+------------------------------------------------------------------+
//| Get text width in pixels                                          |
//+------------------------------------------------------------------+
int GetTextWidth(string text, string font, int fontSize)
{
   g_canvas.FontSet(font, -fontSize * 10);
   int tw = 0, th = 0;
   g_canvas.TextSize(text, tw, th);
   return tw;
}

//+------------------------------------------------------------------+
//| Get text height in pixels                                         |
//+------------------------------------------------------------------+
int GetTextHeight(string text, string font, int fontSize)
{
   g_canvas.FontSet(font, -fontSize * 10);
   int tw = 0, th = 0;
   g_canvas.TextSize(text, tw, th);
   return th;
}

//+------------------------------------------------------------------+
//| Draw word-wrapped text, return total height used                   |
//+------------------------------------------------------------------+
int DrawTextWordWrap(int x, int y, int maxWidth, string text, string font, int fontSize, color clr)
{
   string words[];
   int wordCount = StringSplit(text, ' ', words);

   g_canvas.FontSet(font, -fontSize * 10);

   string currentLine = "";
   int currentY = y;
   int lineHeight = fontSize + 5;

   for(int i = 0; i < wordCount; i++)
   {
      string testLine = (currentLine == "") ? words[i] : currentLine + " " + words[i];
      int tw = 0, th = 0;
      g_canvas.TextSize(testLine, tw, th);

      if(tw > maxWidth && currentLine != "")
      {
         g_canvas.TextOut(x, currentY, currentLine, ToARGB(clr));
         currentLine = words[i];
         currentY += lineHeight;
      }
      else
      {
         currentLine = testLine;
      }
   }

   if(currentLine != "")
   {
      g_canvas.TextOut(x, currentY, currentLine, ToARGB(clr));
      currentY += lineHeight;
   }

   return currentY - y;
}

//+------------------------------------------------------------------+
//| Draw a filled circle                                              |
//+------------------------------------------------------------------+
void FillCircle(int cx, int cy, int radius, color clr, uchar alpha = 255)
{
   g_canvas.FillCircle(cx, cy, radius, ToARGB(clr, alpha));
}

//+------------------------------------------------------------------+
//| Draw arc (approximated with line segments)                        |
//+------------------------------------------------------------------+
void DrawArc(int cx, int cy, int radius, double startAngle, double endAngle, color clr, int thickness = 1)
{
   double step = 2.0;
   for(double angle = startAngle; angle < endAngle; angle += step)
   {
      double rad1 = angle * M_PI / 180.0;
      double rad2 = (angle + step) * M_PI / 180.0;

      int x1 = cx + (int)(radius * MathCos(rad1));
      int y1 = cy - (int)(radius * MathSin(rad1));
      int x2 = cx + (int)(radius * MathCos(rad2));
      int y2 = cy - (int)(radius * MathSin(rad2));

      for(int t = -thickness / 2; t <= thickness / 2; t++)
         g_canvas.Line(x1, y1 + t, x2, y2 + t, ToARGB(clr));
   }
}

//+------------------------------------------------------------------+
//| Draw pointer line (for gauge)                                     |
//+------------------------------------------------------------------+
void DrawPointer(int cx, int cy, int length, double angleDeg, color clr, int thickness = 2)
{
   double rad = angleDeg * M_PI / 180.0;
   int x = cx + (int)(length * MathCos(rad));
   int y = cy - (int)(length * MathSin(rad));

   for(int t = -thickness / 2; t <= thickness / 2; t++)
   {
      g_canvas.Line(cx + t, cy, x + t, y, ToARGB(clr));
      g_canvas.Line(cx, cy + t, x, y + t, ToARGB(clr));
   }

   FillCircle(x, y, 4, clr);
}

//+------------------------------------------------------------------+
//| Draw panel background with header                                 |
//+------------------------------------------------------------------+
void DrawPanelFrame(int x, int y, int w, int h, string title)
{
   // Background
   FillRect(x, y, w, h, g_PanelBackgroundColor);

   // Border
   DrawRect(x, y, w, h, g_TextColor, 80);

   // Header bar
   FillRect(x, y, w, 28, C'40,40,40');
   DrawText(x + 8, y + 5, title, Input_PrimaryFont, Input_BaseFontSize, g_HeaderTextColor);
}

//+------------------------------------------------------------------+
//| Apply color theme                                                 |
//+------------------------------------------------------------------+
void ApplyColorTheme(ENUM_COLOR_THEME theme)
{
   switch(theme)
   {
      case THEME_CLASSIC_GREEN_RED:
         g_BullCandleColor = C'0,170,0';   g_BearCandleColor = C'170,0,0';
         g_BuyTextColor    = C'0,255,0';   g_SellTextColor   = C'255,0,0';
         break;
      case THEME_BLUE_ORANGE:
         g_BullCandleColor = C'255,136,0';  g_BearCandleColor = C'0,136,255';
         g_BuyTextColor    = C'255,170,51'; g_SellTextColor   = C'51,153,255';
         break;
      case THEME_CYAN_MAGENTA:
         g_BullCandleColor = C'0,220,220';  g_BearCandleColor = C'220,0,220';
         g_BuyTextColor    = C'0,255,255';  g_SellTextColor   = C'255,0,255';
         break;
      case THEME_LIME_PINK:
         g_BullCandleColor = C'150,255,0';  g_BearCandleColor = C'255,100,150';
         g_BuyTextColor    = C'200,255,0';  g_SellTextColor   = C'255,150,180';
         break;
      case THEME_GOLD_PURPLE:
         g_BullCandleColor = C'255,215,0';  g_BearCandleColor = C'128,0,128';
         g_BuyTextColor    = C'255,225,50'; g_SellTextColor   = C'180,0,180';
         break;
      case THEME_TEAL_CORAL:
         g_BullCandleColor = C'0,180,170';  g_BearCandleColor = C'255,127,80';
         g_BuyTextColor    = C'0,220,210';  g_SellTextColor   = C'255,160,120';
         break;
      case THEME_SKY_CRIMSON:
         g_BullCandleColor = C'100,180,255'; g_BearCandleColor = C'220,20,60';
         g_BuyTextColor    = C'135,206,250'; g_SellTextColor   = C'255,50,80';
         break;
      case THEME_MINT_ROSE:
         g_BullCandleColor = C'100,255,200'; g_BearCandleColor = C'255,100,150';
         g_BuyTextColor    = C'150,255,220'; g_SellTextColor   = C'255,150,180';
         break;
      case THEME_ORANGE_DARK_GREY:
         g_BullCandleColor = C'255,165,0';   g_BearCandleColor = C'100,100,100';
         g_BuyTextColor    = C'255,200,50';  g_SellTextColor   = C'160,160,160';
         break;
      case THEME_GREEN_DARK_GREY:
         g_BullCandleColor = C'0,200,0';     g_BearCandleColor = C'100,100,100';
         g_BuyTextColor    = C'0,255,0';     g_SellTextColor   = C'160,160,160';
         break;
      case THEME_NAVY_SLATE:
         g_BullCandleColor = C'70,130,180';  g_BearCandleColor = C'112,128,144';
         g_BuyTextColor    = C'100,160,210'; g_SellTextColor   = C'150,160,170';
         break;
      case THEME_NAVY_GOLD:
         g_BullCandleColor = C'255,215,0';   g_BearCandleColor = C'0,0,128';
         g_BuyTextColor    = C'255,225,50';  g_SellTextColor   = C'50,50,180';
         break;
      case THEME_WHITE_DARK_GREY:
         g_BullCandleColor = C'230,230,230'; g_BearCandleColor = C'80,80,80';
         g_BuyTextColor    = C'255,255,255'; g_SellTextColor   = C'120,120,120';
         break;
      case THEME_EMERALD_WHITE:
         g_BullCandleColor = C'0,180,100';   g_BearCandleColor = C'200,200,200';
         g_BuyTextColor    = C'50,220,130';  g_SellTextColor   = C'230,230,230';
         break;
      case THEME_CHERRY_TEAL:
         g_BullCandleColor = C'0,170,170';   g_BearCandleColor = C'180,30,50';
         g_BuyTextColor    = C'0,220,220';   g_SellTextColor   = C'220,50,70';
         break;
      case THEME_OLIVE_SANDY:
         g_BullCandleColor = C'128,128,0';   g_BearCandleColor = C'210,180,140';
         g_BuyTextColor    = C'180,180,0';   g_SellTextColor   = C'230,200,160';
         break;
   }

   // Derived colors
   g_BullishTextColor = g_BuyTextColor;
   g_BearishTextColor = g_SellTextColor;

   if(Input_ThemeOverrideAll)
   {
      g_ImbalanceTier1BuyColor  = g_BullCandleColor;
      g_ImbalanceTier1SellColor = g_BearCandleColor;
      g_ImbalanceTier2BuyColor  = g_BuyTextColor;
      g_ImbalanceTier2SellColor = g_SellTextColor;
      g_ImbalanceTier3BuyColor  = g_BuyTextColor;
      g_ImbalanceTier3SellColor = g_SellTextColor;
   }
}

//+------------------------------------------------------------------+
//| Get cell intensity color based on buy/sell ratio                  |
//+------------------------------------------------------------------+
color GetIntensityColor(long buyVol, long sellVol)
{
   long total = buyVol + sellVol;
   if(total == 0)
      return Input_NeutralCellColor;

   double buyPct = (double)buyVol / total * 100.0;

   if(buyPct >= Input_HighIntensityThreshold)
      return Input_BuyerHighColor;
   if(buyPct >= Input_MediumIntensityThreshold)
      return Input_BuyerMediumColor;
   if(buyPct > (100.0 - Input_MediumIntensityThreshold))
      return Input_BuyerLowColor;

   double sellPct = 100.0 - buyPct;
   if(sellPct >= Input_HighIntensityThreshold)
      return Input_SellerHighColor;
   if(sellPct >= Input_MediumIntensityThreshold)
      return Input_SellerMediumColor;

   return Input_SellerLowColor;
}

//+------------------------------------------------------------------+
//| Get imbalance cell border color                                   |
//+------------------------------------------------------------------+
color GetImbalanceBorderColor(int level, bool isBuy)
{
   if(level == 0) return clrNONE;
   if(isBuy)
   {
      if(level >= 3) return g_ImbalanceTier3BuyColor;
      if(level >= 2) return g_ImbalanceTier2BuyColor;
      return g_ImbalanceTier1BuyColor;
   }
   else
   {
      if(level >= 3) return g_ImbalanceTier3SellColor;
      if(level >= 2) return g_ImbalanceTier2SellColor;
      return g_ImbalanceTier1SellColor;
   }
}

#endif // RENDER_MQH
