//+------------------------------------------------------------------+
//| StopLossEngine.mqh — APEX_SCALPER                                |
//| Dynamic SL placement with priority:                             |
//|   1. Behind nearest HVP (if InpSLBehindHVP)                   |
//|   2. Fallback to fixed InpSLFixedPoints                        |
//|   3. Behind stacked imbalance if tighter (if InpSLBehindImbal) |
//|   4. Validated against broker minimum stop distance            |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Data/WindowManager.mqh"

class CStopLossEngine
{
private:
    CWindowManager *m_wm;
    double          m_point;
    double          m_min_stop_pts;   // broker minimum stop distance in points

    // Refresh broker minimum stop distance (call before each calculation)
    void refresh_min_stop()
    {
        m_min_stop_pts = (double)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL)
                       * m_point;
        if(m_min_stop_pts < m_point) m_min_stop_pts = m_point;
    }

    // Find the nearest stacked imbalance zone price for SL placement
    double nearest_imbalance_sl(int direction, double entry) const
    {
        FootprintCandle fps[];
        int n = m_wm.GetFootprints(fps);
        int check = MathMin(n, 3);
        double best = 0.0;

        for(int c = 0; c < check; c++)
        {
            for(int r = 0; r < fps[c].row_count; r++)
            {
                // For longs: look for bearish imbalance BELOW entry → SL behind it
                if(direction == 1 &&
                   (fps[c].rows[r].bid_imbalance || fps[c].rows[r].zero_ask) &&
                   fps[c].rows[r].price < entry)
                {
                    if(best == 0.0 || fps[c].rows[r].price > best)
                        best = fps[c].rows[r].price;  // highest bearish zone below entry
                }
                // For shorts: look for bullish imbalance ABOVE entry → SL behind it
                if(direction == -1 &&
                   (fps[c].rows[r].ask_imbalance || fps[c].rows[r].zero_bid) &&
                   fps[c].rows[r].price > entry)
                {
                    if(best == 0.0 || fps[c].rows[r].price < best)
                        best = fps[c].rows[r].price;  // lowest bullish zone above entry
                }
            }
        }
        return best;
    }

public:
    bool Initialize(CWindowManager *wm)
    {
        if(wm == NULL) return false;
        m_wm   = wm;
        m_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        if(m_point <= 0.0) m_point = 0.00001;
        return true;
    }

    // Calculate SL price for a trade. direction: +1 long, -1 short.
    // Returns 0.0 on failure (caller must reject the trade).
    double Calculate(int direction, double entry_price)
    {
        refresh_min_stop();
        double sl        = 0.0;
        double buffer    = InpSLBufferPoints * m_point;
        double fixed_sl  = InpSLFixedPoints  * m_point;
        double search_range = fixed_sl * 2.0;

        // Step 1: HVP-based SL
        if(InpSLBehindHVP && m_wm != NULL && m_wm.GetVolumeProfile() != NULL)
        {
            CVolumeProfile *vp = m_wm.GetVolumeProfile();
            if(direction == 1)
            {
                double hvp = vp.GetNearestHVPBelow(entry_price);
                if(hvp > 0.0 && entry_price - hvp <= search_range)
                    sl = hvp - buffer;
            }
            else
            {
                double hvp = vp.GetNearestHVPAbove(entry_price);
                if(hvp > 0.0 && hvp - entry_price <= search_range)
                    sl = hvp + buffer;
            }
        }

        // Step 2: Fixed fallback if no HVP found within range
        if(sl == 0.0)
            sl = (direction == 1) ? entry_price - fixed_sl
                                  : entry_price + fixed_sl;

        // Step 3: Stacked imbalance alternative (use if tighter than HVP SL)
        if(InpSLBehindImbalance && m_wm != NULL)
        {
            double imb = nearest_imbalance_sl(direction, entry_price);
            if(imb > 0.0)
            {
                double imb_sl = (direction == 1) ? imb - buffer : imb + buffer;
                double cur_dist = MathAbs(entry_price - sl);
                double imb_dist = MathAbs(entry_price - imb_sl);
                if(imb_dist < cur_dist && imb_dist > m_min_stop_pts)
                    sl = imb_sl;
            }
        }

        // Step 4: Enforce broker minimum stop distance
        double min_sl = (direction == 1) ? entry_price - m_min_stop_pts
                                         : entry_price + m_min_stop_pts;
        if(direction == 1 && sl > min_sl) sl = min_sl;
        if(direction ==-1 && sl < min_sl) sl = min_sl;

        // Final validation
        if(sl <= 0.0) return 0.0;
        double dist = MathAbs(entry_price - sl);
        if(dist < m_min_stop_pts) return 0.0;

        return NormalizeDouble(sl, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    }
};
