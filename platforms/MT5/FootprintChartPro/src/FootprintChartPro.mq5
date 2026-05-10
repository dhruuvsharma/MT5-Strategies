//+------------------------------------------------------------------+
//| FootprintChartPro.mq5                                             |
//| Professional OrderFlow EA - Delta Cells Edition                   |
//| Canvas-based footprint chart with 11 analysis panels              |
//+------------------------------------------------------------------+
#property copyright "FootprintChartPro"
#property version   "1.00"
#property strict
#property description "Professional order flow visualization with delta cells footprint"

//+------------------------------------------------------------------+
//| Includes                                                          |
//+------------------------------------------------------------------+
#include "Config.mqh"
#include "Market.mqh"
#include "Signal.mqh"
#include "Render.mqh"
#include "Panels.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[", EA_NAME, "] Initializing v", EA_VERSION, " on ", _Symbol, " ", EnumToString(_Period));

   // Apply color theme
   ApplyColorTheme(Input_Theme);

   // Create canvas
   if(!InitCanvas())
   {
      Print("[", EA_NAME, "] Canvas initialization failed");
      return INIT_FAILED;
   }

   // Initialize indicator handles
   if(!InitIndicators())
   {
      Print("[", EA_NAME, "] Indicator initialization failed");
      return INIT_FAILED;
   }

   // Initialize DOM
   if(!InitializeDOMPanel())
      Print("[", EA_NAME, "] DOM not available — panel will show 'No DOM data'");

   // Initialize arrays
   ArrayResize(g_tsTicks, Input_MaxTSHistory);
   g_tsTickCount = 0;

   // Load historical footprint data
   LoadHistoricalFootprintData();

   // Calculate initial volume profile
   CalculateVolumeProfile();

   // Detect S&D zones
   DetectSupplyDemandZones();

   // Fetch economic calendar
   FetchEconomicCalendar();
   g_lastCalendarUpdate = TimeCurrent();

   // Initial mini session chart
   UpdateMiniSessionChart();

   // Generate initial analyst report
   GenerateChartAnalystReport();
   g_lastAnalystUpdate = TimeCurrent();

   // Set timer for periodic refresh
   EventSetMillisecondTimer(Input_RefreshRateMS);

   Print("[", EA_NAME, "] Initialization complete");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[", EA_NAME, "] Deinitializing. Reason: ", reason);

   EventKillTimer();
   CleanupDOMPanel();
   ReleaseIndicators();
   DestroyCanvas();

   Print("[", EA_NAME, "] Cleanup complete");
}

//+------------------------------------------------------------------+
//| Tick handler — processes each incoming tick                        |
//+------------------------------------------------------------------+
void OnTick()
{
   ProcessTick();
}

//+------------------------------------------------------------------+
//| Timer handler — refreshes canvas at configured rate               |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Periodic analyst report update
   if(TimeCurrent() - g_lastAnalystUpdate >= Input_AnalystRefreshSeconds)
   {
      GenerateChartAnalystReport();
      g_lastAnalystUpdate = TimeCurrent();
   }

   // Periodic calendar update
   if(TimeCurrent() - g_lastCalendarUpdate >= Input_CalendarRefreshSeconds)
   {
      FetchEconomicCalendar();
      g_lastCalendarUpdate = TimeCurrent();
   }

   // Recalculate volume profile when needed
   if(g_volumeProfileNeedsRedraw)
   {
      CalculateVolumeProfile();
      g_volumeProfileNeedsRedraw = false;
   }

   // Update mini session chart periodically
   UpdateMiniSessionChart();

   // Render all panels
   RefreshAllPanels();
}

//+------------------------------------------------------------------+
//| Book event handler — DOM data update                              |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
   if(symbol != _Symbol) return;

   MqlBookInfo book[];
   if(MarketBookGet(_Symbol, book))
   {
      UpdateDOMData(book);
      g_domNeedsRedraw = true;
   }
}

//+------------------------------------------------------------------+
//| Render all panels to canvas                                       |
//+------------------------------------------------------------------+
void RefreshAllPanels()
{
   ClearCanvas();

   // Main footprint panel
   RenderDeltaCellsFootprint();

   // Supply & Demand zones (overlay on footprint)
   RenderSupplyDemandZones();

   // Summary table
   RenderSummaryTable();

   // DOM panel
   RenderDOMPanel();

   // Volume profile
   RenderVolumeProfilePanel();

   // Time & Sales
   RenderTimeAndSalesPanel();

   // Signal meter gauge
   RenderSignalMeterGauge();

   // Chart analyst
   RenderChartAnalystPanel();

   // RSI panel
   RenderRSIPanel();

   // MACD panel
   RenderMACDPanel();

   // Economic calendar
   RenderEconomicCalendarPanel();

   // Mini session chart
   RenderMiniSessionChart();

   // Flush canvas to screen
   FlushCanvas();
}

//+------------------------------------------------------------------+
