//+------------------------------------------------------------------+
//| FootprintBuilder.mqh — APEX_SCALPER                              |
//| Builds per-candle footprint: bid/ask volume at each price level. |
//| Runs imbalance scan on bar close, detects stacked imbalances,   |
//| computes POC and Value Area per footprint candle.               |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/RingBuffer.mqh"
#include "../Utils/MathUtils.mqh"
#include "TickCollector.mqh"

//+------------------------------------------------------------------+
//| Price level accumulator used while building the current candle  |
//+------------------------------------------------------------------+
struct FPAccumRow
{
    long  price_level;   // quantized: MathRound(price / tick_size)
    long  bid_vol;
    long  ask_vol;
};

//+------------------------------------------------------------------+
//| CFootprintBuilder                                                |
//+------------------------------------------------------------------+
class CFootprintBuilder
{
private:
    CRingBuffer<FootprintCandle> m_complete;   // finalized footprint candles
    FPAccumRow                   m_accum[APEX_MAX_FOOTPRINT_ROWS];  // fixed accumulator
    int                          m_accum_count;
    datetime                     m_current_bar;
    bool                         m_bar_open;
    double                       m_tick_size;  // symbol tick size
    double                       m_point;      // symbol point

    // Find or create an accumulator row for a quantized price level
    int find_or_create_row(long level)
    {
        for(int i = 0; i < m_accum_count; i++)
            if(m_accum[i].price_level == level) return i;
        // Create new row if space allows
        if(m_accum_count >= APEX_MAX_FOOTPRINT_ROWS) return -1;
        m_accum[m_accum_count].price_level = level;
        m_accum[m_accum_count].bid_vol     = 0;
        m_accum[m_accum_count].ask_vol     = 0;
        return m_accum_count++;
    }

    // Sort accumulator rows by price level ascending (insertion sort — small N)
    void sort_rows_ascending()
    {
        for(int i = 1; i < m_accum_count; i++)
        {
            FPAccumRow key = m_accum[i];
            int j = i - 1;
            while(j >= 0 && m_accum[j].price_level > key.price_level)
            {
                m_accum[j + 1] = m_accum[j];
                j--;
            }
            m_accum[j + 1] = key;
        }
    }

    // Run imbalance scan and compute POC / Value Area on the sorted rows
    FootprintCandle build_candle(datetime bar_time)
    {
        sort_rows_ascending();

        FootprintCandle fc;
        ZeroMemory(fc);
        fc.time        = bar_time;
        fc.row_count   = m_accum_count;
        fc.is_complete = true;

        long total_vol   = 0;
        long max_vol     = 0;
        int  poc_idx     = 0;

        // Pass 1: fill rows, find POC
        for(int i = 0; i < m_accum_count; i++)
        {
            double price = m_accum[i].price_level * m_tick_size * InpFootprintTickSize;
            fc.rows[i].price    = price;
            fc.rows[i].bid_vol  = m_accum[i].bid_vol;
            fc.rows[i].ask_vol  = m_accum[i].ask_vol;
            fc.rows[i].delta    = m_accum[i].ask_vol - m_accum[i].bid_vol;

            long row_vol = m_accum[i].bid_vol + m_accum[i].ask_vol;
            total_vol += row_vol;
            if(row_vol > max_vol) { max_vol = row_vol; poc_idx = i; }

            // Imbalance flags
            long b = m_accum[i].bid_vol;
            long a = m_accum[i].ask_vol;
            fc.rows[i].zero_bid = (b == 0 && a > 0);
            fc.rows[i].zero_ask = (a == 0 && b > 0);
            if(a > 0 && b > 0)
            {
                double ratio_ask = (double)a / b;
                double ratio_bid = (double)b / a;
                fc.rows[i].ask_imbalance = (ratio_ask >= InpImbalanceRatio);
                fc.rows[i].bid_imbalance = (ratio_bid >= InpImbalanceRatio);
            }
            else
            {
                fc.rows[i].ask_imbalance = fc.rows[i].zero_bid; // full ask side
                fc.rows[i].bid_imbalance = fc.rows[i].zero_ask; // full bid side
            }
        }

        fc.poc_price  = (m_accum_count > 0) ? fc.rows[poc_idx].price : 0.0;
        fc.poc_volume = max_vol;

        // Pass 2: stacked imbalance detection (consecutive same-direction rows)
        int bull_streak = 0, bear_streak = 0;
        int max_bull = 0, max_bear = 0;
        for(int i = 0; i < m_accum_count; i++)
        {
            if(fc.rows[i].zero_ask || fc.rows[i].ask_imbalance)
            {
                bull_streak++;
                bear_streak = 0;
            }
            else if(fc.rows[i].zero_bid || fc.rows[i].bid_imbalance)
            {
                bear_streak++;
                bull_streak = 0;
            }
            else
            {
                bull_streak = 0;
                bear_streak = 0;
            }
            if(bull_streak > max_bull) max_bull = bull_streak;
            if(bear_streak > max_bear) max_bear = bear_streak;
        }
        fc.stacked_bull_imbalance = max_bull;
        fc.stacked_bear_imbalance = max_bear;

        // Pass 3: Value Area (70% of total volume) — expand from POC outward
        if(total_vol > 0)
        {
            long va_vol   = 0;
            long va_target = (long)(total_vol * APEX_VALUE_AREA_PCT);
            int  lo = poc_idx, hi = poc_idx;
            va_vol += fc.rows[poc_idx].bid_vol + fc.rows[poc_idx].ask_vol;

            while(va_vol < va_target && (lo > 0 || hi < m_accum_count - 1))
            {
                long vol_above = (hi < m_accum_count - 1)
                    ? fc.rows[hi + 1].bid_vol + fc.rows[hi + 1].ask_vol : 0;
                long vol_below = (lo > 0)
                    ? fc.rows[lo - 1].bid_vol + fc.rows[lo - 1].ask_vol : 0;

                if(vol_above >= vol_below && hi < m_accum_count - 1)
                    va_vol += fc.rows[++hi].bid_vol + fc.rows[hi].ask_vol;
                else if(lo > 0)
                    va_vol += fc.rows[--lo].bid_vol + fc.rows[lo].ask_vol;
                else if(hi < m_accum_count - 1)
                    va_vol += fc.rows[++hi].bid_vol + fc.rows[hi].ask_vol;
                else break;
            }
            fc.value_area_low  = fc.rows[lo].price;
            fc.value_area_high = fc.rows[hi].price;
        }

        return fc;
    }

    // Reset accumulator for a new bar
    void reset_accum()
    {
        m_accum_count = 0;
    }

public:
    // Allocate buffers; call once in OnInit
    bool Initialize(int window_size)
    {
        m_tick_size   = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        m_point       = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        if(m_tick_size <= 0.0) m_tick_size = m_point;
        if(m_tick_size <= 0.0) m_tick_size = 0.00001;

        m_bar_open    = false;
        m_current_bar = 0;
        m_accum_count = 0;

        return m_complete.Initialize(window_size + 10);
    }

    // Process the latest classified tick; call after CandleBuilder.OnTick()
    void OnTick(const ApexTick &t)
    {
        datetime bar_time = iTime(Symbol(), InpTimeframe, 0);
        if(bar_time == 0) return;

        if(!m_bar_open)
        {
            reset_accum();
            m_current_bar = bar_time;
            m_bar_open    = true;
        }
        else if(bar_time != m_current_bar)
        {
            // New bar: finalize and push the completed footprint
            FootprintCandle fc = build_candle(m_current_bar);
            m_complete.Push(fc);
            reset_accum();
            m_current_bar = bar_time;
        }

        // Accumulate this tick into the current bar
        // Quantize price: each row covers InpFootprintTickSize ticks
        if(t.last <= 0.0) return;
        long level = (long)MathRound(t.last / (m_tick_size * InpFootprintTickSize));
        int  idx   = find_or_create_row(level);
        if(idx < 0) return; // row limit reached

        if(t.direction ==  1) m_accum[idx].ask_vol += t.volume;
        if(t.direction == -1) m_accum[idx].bid_vol += t.volume;
    }

    // Returns the most recently finalized FootprintCandle (0 = newest)
    FootprintCandle GetCandle(int bars_back) const
    {
        FootprintCandle empty = {};
        if(bars_back < 0 || bars_back >= m_complete.Size()) return empty;
        FootprintCandle r = {};
        m_complete.Get(bars_back, r);
        return r;
    }

    // Fill out[] with all complete footprint candles newest-first; returns count
    int GetWindow(FootprintCandle &out[]) const
    {
        return m_complete.ToArray(out);
    }

    // Fill out[] with the last N complete footprint candles; returns count written
    int GetLastN(int n, FootprintCandle &out[]) const
    {
        int available = MathMin(n, m_complete.Size());
        ArrayResize(out, available);
        for(int i = 0; i < available; i++)
            m_complete.Get(i, out[i]);
        return available;
    }

    // Returns a live (incomplete) snapshot of the current bar's footprint
    FootprintCandle GetCurrentSnapshot()
    {
        return build_candle(m_current_bar);
    }

    // Number of complete footprint candles stored
    int CompleteCount() const { return m_complete.Size(); }

    // True once at least InpWindowSize footprint candles are complete
    bool IsReady() const { return m_complete.Size() >= InpWindowSize; }

    // Open time of the bar currently being built
    datetime GetCurrentBarTime() const { return m_current_bar; }
};
