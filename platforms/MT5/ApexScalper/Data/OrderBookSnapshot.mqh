//+------------------------------------------------------------------+
//| OrderBookSnapshot.mqh — APEX_SCALPER                             |
//| Captures order book depth snapshots via MarketBookGet().        |
//| Computes OBI (L1/L3/L5/L10), weighted OBI, largest levels,     |
//| spoof detection, OBI momentum. 50-snapshot ring buffer.        |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/RingBuffer.mqh"
#include "../Utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| COrderBookSnapshot                                               |
//+------------------------------------------------------------------+
class COrderBookSnapshot
{
private:
    CRingBuffer<OrderBookSnapshot> m_buffer;   // last 50 snapshots
    uint   m_last_tick_count;                  // GetTickCount() at last snapshot
    bool   m_ready;                            // true once first snapshot taken

    // Compute OBI for the first `levels` bid/ask entries
    double compute_obi(const MqlBookInfo &book[], int bid_count, int ask_count,
                       int levels) const
    {
        long sum_bid = 0, sum_ask = 0;
        int  b_used  = MathMin(levels, bid_count);
        int  a_used  = MathMin(levels, ask_count);
        for(int i = 0; i < b_used; i++) sum_bid += (long)book[i].volume;
        // asks are stored after bids in the MqlBookInfo array
        for(int i = bid_count; i < bid_count + a_used; i++) sum_ask += (long)book[i].volume;
        long total = sum_bid + sum_ask;
        if(total == 0) return 0.0;
        return (double)(sum_bid - sum_ask) / (double)total;
    }

    // Compute exponentially weighted OBI across `levels`
    double compute_weighted_obi(const MqlBookInfo &book[], int bid_count,
                                int ask_count, int levels, double decay) const
    {
        int   b_used = MathMin(levels, bid_count);
        int   a_used = MathMin(levels, ask_count);
        double num = 0.0, den = 0.0;
        int   max_lvl = MathMax(b_used, a_used);
        for(int i = 0; i < max_lvl; i++)
        {
            double w = ExponentialDecayWeight(i, decay);
            long   bv = (i < b_used) ? (long)book[i].volume : 0;
            long   av = (i < a_used) ? (long)book[bid_count + i].volume : 0;
            num += w * (bv - av);
            den += w * (bv + av);
        }
        if(MathAbs(den) < 1e-10) return 0.0;
        return num / den;
    }

    // Detect if a large level in snap `candidate` vanished by snap `current`
    bool level_vanished(double price, long vol_threshold,
                        const OrderBookSnapshot &snap) const
    {
        // Check if `price` still appears on bid side with significant volume
        for(int i = 0; i < snap.depth && i < 20; i++)
        {
            if(MathAbs(snap.bids[i].price - price) < 1e-10)
                return snap.bids[i].volume < vol_threshold / 2;
        }
        for(int i = 0; i < snap.depth && i < 20; i++)
        {
            if(MathAbs(snap.asks[i].price - price) < 1e-10)
                return snap.asks[i].volume < vol_threshold / 2;
        }
        return true; // level gone entirely
    }

public:
    // Allocate ring buffer; call once in OnInit
    bool Initialize()
    {
        m_last_tick_count = 0;
        m_ready           = false;
        return m_buffer.Initialize(APEX_MAX_OB_SNAPSHOTS);
    }

    // Take a snapshot; call from OnBookEvent() or throttled from OnTick()
    bool TakeSnapshot()
    {
        MqlBookInfo book[];
        if(!MarketBookGet(Symbol(), book)) return false;
        int total = ArraySize(book);
        if(total == 0) return false;

        // Split into bids (BOOK_TYPE_BID) and asks (BOOK_TYPE_ASK)
        // MarketBookGet returns: bids descending by price first, then asks ascending
        int bid_count = 0, ask_count = 0;
        for(int i = 0; i < total; i++)
        {
            if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
                bid_count++;
            else
                ask_count++;
        }
        // Determine actual split index
        int bid_end = 0;
        for(int i = 0; i < total; i++)
        {
            if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
                bid_end = i + 1;
            else
                break;
        }
        bid_count = bid_end;
        ask_count = total - bid_count;

        OrderBookSnapshot snap;
        ZeroMemory(snap);
        snap.time  = TimeCurrent();
        snap.depth = MathMin(MathMin(bid_count, ask_count), 20);

        // Fill bid/ask arrays (up to 20 levels each)
        for(int i = 0; i < MathMin(bid_count, 20); i++)
        {
            snap.bids[i].price  = book[i].price;
            snap.bids[i].volume = (long)book[i].volume;
        }
        for(int i = 0; i < MathMin(ask_count, 20); i++)
        {
            snap.asks[i].price  = book[bid_count + i].price;
            snap.asks[i].volume = (long)book[bid_count + i].volume;
        }

        // Best bid/ask and spread
        if(bid_count > 0 && ask_count > 0)
        {
            snap.mid_price = (book[0].price + book[bid_count].price) * 0.5;
            snap.spread    = (book[bid_count].price - book[0].price)
                           / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        }

        // OBI at multiple depths
        snap.obi_l1  = compute_obi(book, bid_count, ask_count, 1);
        snap.obi_l3  = compute_obi(book, bid_count, ask_count,
                                   MathMin(InpOBILevelsShallow, 3));
        snap.obi_l5  = compute_obi(book, bid_count, ask_count, 5);
        snap.obi_l10 = compute_obi(book, bid_count, ask_count,
                                   MathMin(InpOBILevelsDeep, 10));
        snap.weighted_obi = compute_weighted_obi(book, bid_count, ask_count,
                                                 InpOBILevelsDeep, InpOBIWeightDecay);

        // Total volumes
        for(int i = 0; i < bid_count; i++) snap.total_bid_vol += (double)book[i].volume;
        for(int i = bid_count; i < total; i++) snap.total_ask_vol += (double)book[i].volume;

        // Largest single level on each side
        for(int i = 0; i < MathMin(bid_count, 20); i++)
        {
            if(snap.bids[i].volume > snap.largest_bid_level_vol)
            {
                snap.largest_bid_level_vol = snap.bids[i].volume;
                snap.largest_bid_price     = snap.bids[i].price;
            }
        }
        for(int i = 0; i < MathMin(ask_count, 20); i++)
        {
            if(snap.asks[i].volume > snap.largest_ask_level_vol)
            {
                snap.largest_ask_level_vol = snap.asks[i].volume;
                snap.largest_ask_price     = snap.asks[i].price;
            }
        }

        // Spoof detection: check if largest level from N snaps ago has vanished
        int spoof_lookback = (int)InpOBISpoofDetectSnap;
        if(m_buffer.Size() >= spoof_lookback)
        {
            OrderBookSnapshot old_snap;
            m_buffer.Get(spoof_lookback - 1, old_snap);
            long vol_thresh = old_snap.largest_bid_level_vol;
            double price    = old_snap.largest_bid_price;
            if(vol_thresh > 0 && level_vanished(price, vol_thresh, snap))
                snap.spoof_suspected = true;

            vol_thresh = old_snap.largest_ask_level_vol;
            price      = old_snap.largest_ask_price;
            if(vol_thresh > 0 && level_vanished(price, vol_thresh, snap))
                snap.spoof_suspected = true;
        }

        m_buffer.Push(snap);
        m_last_tick_count = GetTickCount();
        m_ready           = true;
        return true;
    }

    // Returns the most recently taken snapshot
    OrderBookSnapshot GetLatestSnapshot() const
    {
        OrderBookSnapshot s = {};
        m_buffer.Get(0, s);
        return s;
    }

    // Fill out[] with the last N snapshots newest-first; returns count written
    int GetSnapshotHistory(int n, OrderBookSnapshot &out[]) const
    {
        int available = MathMin(n, m_buffer.Size());
        ArrayResize(out, available);
        for(int i = 0; i < available; i++)
            m_buffer.Get(i, out[i]);
        return available;
    }

    // OBI momentum: linear regression slope of weighted_obi over last `periods`
    double ComputeOBIMomentum(int periods) const
    {
        int n = MathMin(periods, m_buffer.Size());
        if(n < 2) return 0.0;
        double xs[], ys[];
        ArrayResize(xs, n);
        ArrayResize(ys, n);
        for(int i = 0; i < n; i++)
        {
            OrderBookSnapshot _s;
            m_buffer.Get(n - 1 - i, _s);
            xs[i] = (double)(n - 1 - i);   // 0 = oldest, n-1 = newest
            ys[i] = _s.weighted_obi;
        }
        return LinearRegressionSlope(xs, ys, n);
    }

    // True if a snapshot interval has elapsed since the last snapshot
    bool IsSnapshotDue() const
    {
        return (int)(GetTickCount() - m_last_tick_count) >= InpOBISnapshotInterval;
    }

    // True once at least one snapshot has been taken
    bool IsReady() const { return m_ready; }

    // Number of snapshots currently in the ring buffer
    int SnapshotCount() const { return m_buffer.Size(); }
};
