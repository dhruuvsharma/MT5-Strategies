//+------------------------------------------------------------------+
//| TickCollector.mqh — APEX_SCALPER                                 |
//| Aggregates raw ticks, classifies buy/sell, tracks tape metrics. |
//| Ring buffer of last APEX_MAX_TICK_BUFFER (5000) ApexTick structs.|
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/RingBuffer.mqh"

//+------------------------------------------------------------------+
//| CTickCollector                                                   |
//+------------------------------------------------------------------+
class CTickCollector
{
private:
    CRingBuffer<ApexTick> m_buffer;
    long                  m_tick_index;         // monotonically increasing counter
    MqlTick               m_last_tick;          // previous tick for comparison
    bool                  m_has_prev;           // true once first tick is processed

    // Classify a tick as buy (+1), sell (-1), or unknown (0)
    int classify_direction(const MqlTick &tick) const
    {
        // Live feed: use last-price vs bid/ask
        if(tick.last > 0.0)
        {
            if(tick.last >= tick.ask && tick.ask > 0.0) return  1;
            if(tick.last <= tick.bid && tick.bid > 0.0) return -1;
            return 0;
        }
        // Strategy Tester: tick.last is always 0 — fall back to ask movement
        if(m_has_prev && tick.ask > m_last_tick.ask + 1e-10) return  1;
        if(m_has_prev && tick.ask < m_last_tick.ask - 1e-10) return -1;
        return 0;
    }

public:
    // Allocate ring buffer; call once in OnInit
    bool Initialize()
    {
        m_tick_index = 0;
        m_has_prev   = false;
        ZeroMemory(m_last_tick);
        return m_buffer.Initialize(APEX_MAX_TICK_BUFFER);
    }

    // Process the current tick; call at the top of OnTick()
    void OnTick()
    {
        MqlTick tick;
        if(!SymbolInfoTick(Symbol(), tick)) return;

        // Skip if identical to previous (some brokers repeat ticks)
        if(m_has_prev && tick.time_msc == m_last_tick.time_msc
           && tick.last == m_last_tick.last) return;

        ApexTick at;
        at.time      = tick.time;
        at.bid       = tick.bid;
        at.ask       = tick.ask;
        at.last      = (tick.last > 0.0) ? tick.last : (tick.bid + tick.ask) * 0.5;
        at.volume    = (long)tick.volume;
        at.direction = classify_direction(tick);
        at.spread    = (tick.ask - tick.bid) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        at.index     = m_tick_index++;

        m_buffer.Push(at);
        m_last_tick = tick;
        m_has_prev  = true;
    }

    // Fill out[] with the N most recent ticks (newest first); returns count written
    int GetLastN(int n, ApexTick &out[]) const
    {
        int count = MathMin(n, m_buffer.Size());
        ArrayResize(out, count);
        for(int i = 0; i < count; i++)
            m_buffer.Get(i, out[i]);
        return count;
    }

    // Fill out[] with ticks at or after `since`; returns count written
    int GetTicksSince(datetime since, ApexTick &out[]) const
    {
        int total = m_buffer.Size();
        // Find the oldest tick that qualifies (buffer is newest-first)
        int last_valid = -1;
        for(int i = 0; i < total; i++)
        {
            ApexTick _t;
            m_buffer.Get(i, _t);
            if(_t.time >= since)
                last_valid = i;
            else
                break; // buffer is time-ordered newest→oldest; stop early
        }
        if(last_valid < 0) { ArrayResize(out, 0); return 0; }
        int count = last_valid + 1;
        ArrayResize(out, count);
        for(int i = 0; i < count; i++)
            m_buffer.Get(i, out[i]);
        return count;
    }

    // Trades per second in the last `seconds` of wall-clock time
    double GetTapeSpeed(int seconds) const
    {
        if(seconds <= 0) return 0.0;
        datetime cutoff = TimeCurrent() - seconds;
        int count = 0;
        for(int i = 0; i < m_buffer.Size(); i++)
        {
            ApexTick _t;
            m_buffer.Get(i, _t);
            if(_t.time < cutoff) break;
            count++;
        }
        return (double)count / seconds;
    }

    // Fraction of ticks in last `seconds` that are buy-initiated (+1)
    double GetDirectionalFraction(int seconds) const
    {
        if(seconds <= 0) return 0.5;
        datetime cutoff = TimeCurrent() - seconds;
        int total = 0, buys = 0;
        for(int i = 0; i < m_buffer.Size(); i++)
        {
            ApexTick t;
            m_buffer.Get(i, t);
            if(t.time < cutoff) break;
            if(t.direction != 0) total++;
            if(t.direction == 1) buys++;
        }
        if(total == 0) return 0.5;
        return (double)buys / total;
    }

    // Buy volume in last `seconds` of classified ticks
    long GetBuyVolume(int seconds) const
    {
        datetime cutoff = TimeCurrent() - seconds;
        long vol = 0;
        for(int i = 0; i < m_buffer.Size(); i++)
        {
            ApexTick t;
            m_buffer.Get(i, t);
            if(t.time < cutoff) break;
            if(t.direction == 1) vol += t.volume;
        }
        return vol;
    }

    // Sell volume in last `seconds` of classified ticks
    long GetSellVolume(int seconds) const
    {
        datetime cutoff = TimeCurrent() - seconds;
        long vol = 0;
        for(int i = 0; i < m_buffer.Size(); i++)
        {
            ApexTick t;
            m_buffer.Get(i, t);
            if(t.time < cutoff) break;
            if(t.direction == -1) vol += t.volume;
        }
        return vol;
    }

    // Most recent classified tick (index 0 = newest)
    ApexTick GetLatest() const
    {
        ApexTick t = {};
        m_buffer.Get(0, t);
        return t;
    }

    // Total ticks processed since Initialize()
    long GetTotalTickCount() const { return m_tick_index; }

    // Number of ticks currently in the ring buffer
    int GetBufferSize() const { return m_buffer.Size(); }

    // True once at least one tick has been processed
    bool IsReady() const { return m_has_prev; }
};
