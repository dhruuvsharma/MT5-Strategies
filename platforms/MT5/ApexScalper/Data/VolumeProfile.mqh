//+------------------------------------------------------------------+
//| VolumeProfile.mqh — APEX_SCALPER                                 |
//| Builds a rolling volume-at-price profile across the N-candle    |
//| window. Merges all footprint rows into a unified price→vol map. |
//| Identifies POC, HVPs (std dev threshold), and Value Area.      |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| CVolumeProfile                                                   |
//+------------------------------------------------------------------+
class CVolumeProfile
{
private:
    VPNode  m_nodes[APEX_MAX_VP_NODES];  // unified price→volume map
    int     m_node_count;
    int     m_poc_idx;                   // index of POC node in m_nodes
    double  m_value_area_high;
    double  m_value_area_low;
    double  m_tick_size;                 // symbol tick size
    bool    m_ready;                     // true once Rebuild() has been called once

    // Find existing node index for a price; returns -1 if not found
    int find_node(double price) const
    {
        for(int i = 0; i < m_node_count; i++)
            if(MathAbs(m_nodes[i].price - price) < m_tick_size * 0.5)
                return i;
        return -1;
    }

    // Find or create a node for a price; returns index or -1 on overflow
    int find_or_create(double price)
    {
        int idx = find_node(price);
        if(idx >= 0) return idx;
        if(m_node_count >= APEX_MAX_VP_NODES) return -1;
        ZeroMemory(m_nodes[m_node_count]);
        m_nodes[m_node_count].price = price;
        return m_node_count++;
    }

    // Sort nodes ascending by price (insertion sort — called once per Rebuild)
    void sort_nodes()
    {
        for(int i = 1; i < m_node_count; i++)
        {
            VPNode key = m_nodes[i];
            int j = i - 1;
            while(j >= 0 && m_nodes[j].price > key.price)
            {
                m_nodes[j + 1] = m_nodes[j];
                j--;
            }
            m_nodes[j + 1] = key;
        }
    }

    // Mark HVPs: levels with volume > mean + multiplier * stddev
    void compute_hvps()
    {
        if(m_node_count == 0) return;
        double vols[];
        ArrayResize(vols, m_node_count);
        for(int i = 0; i < m_node_count; i++)
            vols[i] = (double)m_nodes[i].volume;
        double mean = RollingMean(vols, m_node_count);
        double sd   = RollingStdDev(vols, m_node_count, mean);
        double thresh = mean + InpHVPStdDevMultiplier * sd;
        for(int i = 0; i < m_node_count; i++)
            m_nodes[i].is_hvp = (vols[i] > thresh);

        // Fallback: if stddev too low and no nodes passed threshold,
        // guarantee at least top-3 volume nodes are marked as HVP
        int hvp_count = 0;
        for(int i = 0; i < m_node_count; i++)
            if(m_nodes[i].is_hvp) hvp_count++;
        if(hvp_count == 0)
        {
            int top_n = MathMin(3, m_node_count);
            for(int pass = 0; pass < top_n; pass++)
            {
                int  best_idx = -1;
                long best_vol = -1;
                for(int i = 0; i < m_node_count; i++)
                {
                    if(!m_nodes[i].is_hvp && m_nodes[i].volume > best_vol)
                    {
                        best_vol = m_nodes[i].volume;
                        best_idx = i;
                    }
                }
                if(best_idx >= 0) m_nodes[best_idx].is_hvp = true;
            }
        }
    }

    // Compute Value Area (APEX_VALUE_AREA_PCT of total volume) from POC outward
    void compute_value_area(long total_vol)
    {
        if(m_node_count == 0 || total_vol == 0) return;
        long target = (long)(total_vol * APEX_VALUE_AREA_PCT);
        int lo = m_poc_idx, hi = m_poc_idx;
        long accumulated = m_nodes[m_poc_idx].volume;

        while(accumulated < target && (lo > 0 || hi < m_node_count - 1))
        {
            long vol_above = (hi < m_node_count - 1) ? m_nodes[hi + 1].volume : 0;
            long vol_below = (lo > 0)                ? m_nodes[lo - 1].volume : 0;

            if(vol_above >= vol_below && hi < m_node_count - 1)
                accumulated += m_nodes[++hi].volume;
            else if(lo > 0)
                accumulated += m_nodes[--lo].volume;
            else if(hi < m_node_count - 1)
                accumulated += m_nodes[++hi].volume;
            else break;
        }
        m_value_area_low  = m_nodes[lo].price;
        m_value_area_high = m_nodes[hi].price;
    }

public:
    // Cache tick size; call once in OnInit
    bool Initialize()
    {
        m_tick_size   = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        if(m_tick_size <= 0.0)
            m_tick_size = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        m_node_count  = 0;
        m_poc_idx     = 0;
        m_value_area_high = 0.0;
        m_value_area_low  = 0.0;
        m_ready       = false;
        return true;
    }

    // Rebuild the entire profile from the current window of footprint candles
    void Rebuild(const FootprintCandle &footprints[], int fp_count,
                 const ApexCandle     &candles[],    int candle_count)
    {
        m_node_count = 0;
        m_poc_idx    = 0;

        // Merge all footprint rows from every candle in the window
        for(int c = 0; c < fp_count; c++)
        {
            if(!footprints[c].is_complete) continue;
            for(int r = 0; r < footprints[c].row_count; r++)
            {
                if(footprints[c].rows[r].price <= 0.0) continue;
                int idx = find_or_create(footprints[c].rows[r].price);
                if(idx < 0) continue;  // node limit reached
                m_nodes[idx].volume   += footprints[c].rows[r].bid_vol + footprints[c].rows[r].ask_vol;
                m_nodes[idx].buy_vol  += footprints[c].rows[r].ask_vol;
                m_nodes[idx].sell_vol += footprints[c].rows[r].bid_vol;
            }
        }

        // Fallback: if no footprint data, approximate from ApexCandle OHLC midpoints
        if(m_node_count == 0)
        {
            for(int c = 0; c < candle_count; c++)
            {
                if(!candles[c].is_complete) continue;
                double mid = (candles[c].high + candles[c].low) * 0.5;
                int idx = find_or_create(mid);
                if(idx < 0) continue;
                m_nodes[idx].volume   += candles[c].volume;
                m_nodes[idx].buy_vol  += candles[c].buy_volume;
                m_nodes[idx].sell_vol += candles[c].sell_volume;
            }
        }

        if(m_node_count == 0) return;

        sort_nodes();

        // Find POC
        long max_vol = 0;
        long total   = 0;
        for(int i = 0; i < m_node_count; i++)
        {
            total += m_nodes[i].volume;
            m_nodes[i].is_poc = false;
            if(m_nodes[i].volume > max_vol)
            {
                max_vol   = m_nodes[i].volume;
                m_poc_idx = i;
            }
        }
        m_nodes[m_poc_idx].is_poc = true;

        compute_hvps();
        compute_value_area(total);
        m_ready = true;
    }

    // Returns the POC node (highest volume price in the window)
    VPNode GetPOC() const
    {
        if(m_node_count == 0) { VPNode empty = {}; return empty; }
        return m_nodes[m_poc_idx];
    }

    // Fill out[] with all HVP nodes; returns count
    int GetHVPs(VPNode &out[]) const
    {
        int count = 0;
        for(int i = 0; i < m_node_count; i++)
            if(m_nodes[i].is_hvp) count++;
        ArrayResize(out, count);
        int j = 0;
        for(int i = 0; i < m_node_count; i++)
            if(m_nodes[i].is_hvp) out[j++] = m_nodes[i];
        return count;
    }

    // Returns interpolated volume at a given price (0 if not in map)
    long GetVolumeAtPrice(double price) const
    {
        int idx = find_node(price);
        if(idx < 0) return 0;
        return m_nodes[idx].volume;
    }

    // True if the given price is a High Volume Pocket
    bool IsHVP(double price) const
    {
        int idx = find_node(price);
        if(idx < 0) return false;
        return m_nodes[idx].is_hvp;
    }

    // True if the given price falls within the Value Area
    bool IsInValueArea(double price) const
    {
        return price >= m_value_area_low && price <= m_value_area_high;
    }

    // Nearest HVP price below `reference` (for long SL placement)
    double GetNearestHVPBelow(double reference) const
    {
        double best = 0.0;
        for(int i = 0; i < m_node_count; i++)
        {
            if(!m_nodes[i].is_hvp) continue;
            if(m_nodes[i].price < reference)
            {
                if(best == 0.0 || m_nodes[i].price > best)
                    best = m_nodes[i].price;
            }
        }
        return best;
    }

    // Nearest HVP price above `reference` (for short SL placement)
    double GetNearestHVPAbove(double reference) const
    {
        double best = 0.0;
        for(int i = 0; i < m_node_count; i++)
        {
            if(!m_nodes[i].is_hvp) continue;
            if(m_nodes[i].price > reference)
            {
                if(best == 0.0 || m_nodes[i].price < best)
                    best = m_nodes[i].price;
            }
        }
        return best;
    }

    // Value area bounds
    double GetValueAreaHigh() const { return m_value_area_high; }
    double GetValueAreaLow()  const { return m_value_area_low;  }

    // Total number of price nodes in the profile
    int    NodeCount()        const { return m_node_count; }

    // True once Rebuild() has been called at least once
    bool   IsReady()          const { return m_ready; }
};
