//+------------------------------------------------------------------+
//| CandleBuilder.mqh — APEX_SCALPER                                 |
//| Builds enriched ApexCandle structs from the classified tick     |
//| stream. Finalizes candles on bar close. Maintains a ring buffer |
//| of InpWindowSize + 10 complete candles.                         |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/RingBuffer.mqh"
#include "TickCollector.mqh"

//+------------------------------------------------------------------+
//| CCandleBuilder                                                   |
//+------------------------------------------------------------------+
class CCandleBuilder
{
private:
    CRingBuffer<ApexCandle> m_complete;      // finalized candles (newest-first)
    ApexCandle              m_current;       // candle being built right now
    datetime                m_current_bar;  // open time of the bar in progress
    bool                    m_bar_open;     // true once first tick of bar arrives
    int                     m_capacity;     // ring buffer capacity
    double                  m_point;        // symbol point size cached

    // Spread in points for a given bid/ask pair
    double spread_pts(double bid, double ask) const
    {
        return (ask - bid) / m_point;
    }

    // Start a new in-progress candle from the first tick of the bar
    void open_candle(const ApexTick &t, datetime bar_time)
    {
        ZeroMemory(m_current);
        m_current.open_time   = bar_time;
        m_current.open        = t.last;
        m_current.high        = t.last;
        m_current.low         = t.last;
        m_current.close       = t.last;
        m_current.volume      = t.volume;
        m_current.buy_volume  = (t.direction ==  1) ? t.volume : 0;
        m_current.sell_volume = (t.direction == -1) ? t.volume : 0;
        m_current.tick_delta  = m_current.buy_volume - m_current.sell_volume;
        m_current.trade_count = 1;
        m_current.max_spread  = t.spread;
        m_current.avg_spread  = t.spread;
        m_current.is_complete = false;
        m_current_bar         = bar_time;
        m_bar_open            = true;
    }

    // Update the in-progress candle with the next tick
    void update_candle(const ApexTick &t)
    {
        if(t.last > m_current.high)  m_current.high = t.last;
        if(t.last < m_current.low)   m_current.low  = t.last;
        m_current.close       = t.last;
        m_current.volume     += t.volume;
        if(t.direction ==  1) m_current.buy_volume  += t.volume;
        if(t.direction == -1) m_current.sell_volume += t.volume;
        m_current.tick_delta  = m_current.buy_volume - m_current.sell_volume;
        m_current.trade_count++;
        if(t.spread > m_current.max_spread) m_current.max_spread = t.spread;
        // Rolling average spread: cumulative mean
        m_current.avg_spread += (t.spread - m_current.avg_spread) / m_current.trade_count;
    }

    // Finalize the current candle and push to the ring buffer
    void close_candle(datetime close_bar_duration_secs)
    {
        m_current.is_complete     = true;
        // Delta efficiency: |delta| / volume, clamped to [0, 1]
        if(m_current.volume > 0)
            m_current.delta_efficiency = MathMin(
                MathAbs((double)m_current.tick_delta) / m_current.volume, 1.0);
        else
            m_current.delta_efficiency = 0.0;
        // Average trade size
        if(m_current.trade_count > 0)
            m_current.avg_trade_size = (double)m_current.volume / m_current.trade_count;
        // Tape speed: trades per second
        if(close_bar_duration_secs > 0)
            m_current.tape_speed = (double)m_current.trade_count / close_bar_duration_secs;
        else
            m_current.tape_speed = 0.0;

        m_complete.Push(m_current);
        m_bar_open = false;
    }

public:
    // Allocate ring buffer; call once in OnInit after InpWindowSize is known
    bool Initialize(int window_size)
    {
        m_capacity   = window_size + 10;
        m_point      = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        if(m_point <= 0.0) m_point = 0.00001; // fallback
        m_bar_open   = false;
        m_current_bar = 0;
        ZeroMemory(m_current);
        return m_complete.Initialize(m_capacity);
    }

    // Process the latest classified tick; call every OnTick() after TickCollector
    void OnTick(const ApexTick &t)
    {
        // Current bar open time on the primary timeframe
        datetime bar_time = iTime(Symbol(), InpTimeframe, 0);
        if(bar_time == 0) return; // price feed not ready

        if(!m_bar_open)
        {
            // First ever tick — just open the candle
            open_candle(t, bar_time);
            return;
        }

        if(bar_time != m_current_bar)
        {
            // New bar started: finalize the previous candle first
            long duration_secs = bar_time - m_current_bar;
            if(duration_secs <= 0)
                duration_secs = PeriodSeconds(InpTimeframe);
            close_candle((datetime)duration_secs);

            // Open the new candle with this tick
            open_candle(t, bar_time);
        }
        else
        {
            // Same bar — update in progress
            update_candle(t);
        }
    }

    // Returns a copy of the candle currently being built (incomplete)
    ApexCandle GetCurrentCandle() const { return m_current; }

    // Returns a completed candle; 0 = most recently closed, 1 = one before, etc.
    ApexCandle GetCandle(int bars_back) const
    {
        ApexCandle empty = {};
        if(bars_back < 0 || bars_back >= m_complete.Size()) return empty;
        ApexCandle r = {};
        m_complete.Get(bars_back, r);
        return r;
    }

    // Fill out[] with all complete candles newest-first; returns count
    int GetWindow(ApexCandle &out[]) const
    {
        return m_complete.ToArray(out);
    }

    // Fill out[] with the most recent `count` complete candles; returns count written
    int GetLastN(int count, ApexCandle &out[]) const
    {
        int available = MathMin(count, m_complete.Size());
        ArrayResize(out, available);
        for(int i = 0; i < available; i++)
            m_complete.Get(i, out[i]);
        return available;
    }

    // Number of complete candles stored
    int CompleteCount() const { return m_complete.Size(); }

    // True once at least InpWindowSize candles have closed
    bool IsWindowReady() const { return m_complete.Size() >= InpWindowSize; }

    // True if a bar is currently open (first tick has arrived)
    bool IsBarOpen() const { return m_bar_open; }

    // Open time of the bar currently being built
    datetime GetCurrentBarTime() const { return m_current_bar; }
};
