//+------------------------------------------------------------------+
//| WindowManager.mqh — APEX_SCALPER                                 |
//| Central controller for the sliding N-candle window.             |
//| Coordinates CandleBuilder, FootprintBuilder, VolumeProfile.    |
//| Advances the window on every bar close and rebuilds derived     |
//| metrics. Single source of truth for signal layer data access.  |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "CandleBuilder.mqh"
#include "FootprintBuilder.mqh"
#include "VolumeProfile.mqh"

//+------------------------------------------------------------------+
//| CWindowManager                                                   |
//+------------------------------------------------------------------+
class CWindowManager
{
private:
    CCandleBuilder    *m_candles;     // owned externally, pointer only
    CFootprintBuilder *m_footprints; // owned externally, pointer only
    CVolumeProfile    m_vp;           // owned here

    ApexCandle      m_window[];        // snapshot of last InpWindowSize complete candles
    FootprintCandle m_fp_window[];     // snapshot of last InpWindowSize footprint candles
    int             m_window_size;
    datetime        m_last_bar_time;
    bool            m_window_ready;

    // Pull the current window snapshot from CandleBuilder
    void refresh_candle_window()
    {
        ApexCandle all[];
        int total = m_candles.GetWindow(all);
        int take  = MathMin(total, m_window_size);
        ArrayResize(m_window, take);
        for(int i = 0; i < take; i++)
            m_window[i] = all[i];
    }

    // Pull the current footprint window snapshot from FootprintBuilder
    void refresh_fp_window()
    {
        FootprintCandle all[];
        int total = m_footprints.GetWindow(all);
        int take  = MathMin(total, m_window_size);
        ArrayResize(m_fp_window, take);
        for(int i = 0; i < take; i++)
            m_fp_window[i] = all[i];
    }


public:
    // Initialize; pointers to CandleBuilder and FootprintBuilder must remain valid
    bool Initialize(CCandleBuilder *candles, CFootprintBuilder *footprints,
                    int window_size)
    {
        m_candles      = candles;
        m_footprints   = footprints;
        m_window_size  = window_size;
        m_last_bar_time = 0;
        m_window_ready  = false;

        ArrayResize(m_window,    0);
        ArrayResize(m_fp_window, 0);

        return m_vp.Initialize();
    }

    // Call once per tick; detects new bar and drives window advance + VP rebuild
    void OnTick()
    {
        datetime current_bar = iTime(Symbol(), InpTimeframe, 0);
        if(current_bar == 0 || current_bar == m_last_bar_time) return;

        // New bar detected
        m_last_bar_time = current_bar;
        g_BarsProcessed++;
        g_BarsSinceLastTrade++;

        Advance();
    }

    // Advance the window: refresh snapshots, rebuild volume profile, update state
    void Advance()
    {
        refresh_candle_window();
        refresh_fp_window();

        int fp_count     = ArraySize(m_fp_window);
        int candle_count = ArraySize(m_window);

        m_vp.Rebuild(m_fp_window, fp_count, m_window, candle_count);

        m_window_ready = (m_candles.CompleteCount()    >= m_window_size &&
                          m_footprints.CompleteCount() >= m_window_size);

        if((bool)MQLInfoInteger(MQL_TESTER))
            PrintFormat("APEX WM: candles=%d fp=%d vp_nodes=%d vp_ready=%s window_ready=%s",
                        candle_count, fp_count,
                        m_vp.NodeCount(), m_vp.IsReady() ? "YES" : "NO",
                        m_window_ready ? "YES" : "NO");

        g_EventBus.Publish(EVENT_NEW_BAR);
    }

    // Returns true once InpWindowSize bars of both candle and footprint data exist
    bool IsWindowReady() const { return m_window_ready; }

    // Returns a const reference to the current candle window (newest-first)
    int GetWindow(ApexCandle &out[]) const
    {
        int n = ArraySize(m_window);
        ArrayResize(out, n);
        ArrayCopy(out, m_window);
        return n;
    }

    // Returns a const reference to the current footprint window (newest-first)
    int GetFootprints(FootprintCandle &out[]) const
    {
        int n = ArraySize(m_fp_window);
        ArrayResize(out, n);
        ArrayCopy(out, m_fp_window);
        return n;
    }

    // Returns a pointer to the volume profile (valid after first Advance())
    CVolumeProfile* GetVolumeProfile() { return &m_vp; }

    // Returns the most recent complete candle (barsBack=0) or older ones
    ApexCandle GetCandle(int bars_back) const
    {
        ApexCandle empty = {};
        if(bars_back < 0 || bars_back >= ArraySize(m_window)) return empty;
        return m_window[bars_back];
    }

    // Returns the most recent complete footprint candle
    FootprintCandle GetFootprint(int bars_back) const
    {
        FootprintCandle empty = {};
        if(bars_back < 0 || bars_back >= ArraySize(m_fp_window)) return empty;
        return m_fp_window[bars_back];
    }

    // Current live (incomplete) candle from CandleBuilder
    ApexCandle      GetCurrentCandle()    const { return m_candles.GetCurrentCandle();    }

    // Current live (incomplete) footprint snapshot from FootprintBuilder
    FootprintCandle GetCurrentFootprint() { return m_footprints.GetCurrentSnapshot(); }

    // How many complete candles are currently in the window (up to InpWindowSize)
    int WindowCount()      const { return ArraySize(m_window);    }

    // How many complete footprint candles are in the window
    int FootprintCount()   const { return ArraySize(m_fp_window); }

    // Open time of the bar currently being built
    datetime GetCurrentBarTime() const { return m_candles.GetCurrentBarTime(); }
};
