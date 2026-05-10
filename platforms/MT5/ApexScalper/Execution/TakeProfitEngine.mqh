//+------------------------------------------------------------------+
//| TakeProfitEngine.mqh — APEX_SCALPER                              |
//| TP priority:                                                     |
//|   1. Nearest opposing HVP (if InpTPAtOppositeHVP)              |
//|   2. Fallback: entry ± (SL_distance * InpTPFixedRR)            |
//| InpTPTrailingAfterHVP: sets trailing_active flag in TradeContext |
//| when the first HVP TP level is hit (managed in PositionTracker).|
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Data/WindowManager.mqh"
#include "../Signals/VPOCSignal.mqh"

class CTakeProfitEngine
{
private:
    CWindowManager *m_wm;
    CVPOCSignal    *m_vpoc;
    double          m_point;
    double          m_min_stop_pts;

    void refresh_min_stop()
    {
        m_min_stop_pts = (double)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL)
                       * m_point;
        if(m_min_stop_pts < m_point) m_min_stop_pts = m_point;
    }

public:
    bool Initialize(CWindowManager *wm, CVPOCSignal *vpoc)
    {
        if(wm == NULL) return false;
        m_wm   = wm;
        m_vpoc = vpoc;   // NULL-safe: anchor check skipped if NULL
        m_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        if(m_point <= 0.0) m_point = 0.00001;
        return true;
    }

    // Calculate TP price. Returns 0.0 on failure.
    double Calculate(int direction, double entry_price, double sl_price)
    {
        refresh_min_stop();
        double sl_dist = MathAbs(entry_price - sl_price);
        double tp      = 0.0;

        // If VPOC anchor level detected, prefer mean-reversion fixed R:R TP
        bool is_anchor = (m_vpoc != NULL) && m_vpoc.IsAnchorLevel();

        // Step 1: Opposing HVP TP
        if(InpTPAtOppositeHVP && !is_anchor &&
           m_wm != NULL && m_wm.GetVolumeProfile() != NULL)
        {
            CVolumeProfile *vp = m_wm.GetVolumeProfile();
            if(direction == 1)
                tp = vp.GetNearestHVPAbove(entry_price);
            else
                tp = vp.GetNearestHVPBelow(entry_price);

            // Discard if the HVP TP gives worse R:R than InpTPFixedRR
            if(tp > 0.0)
            {
                double tp_dist = MathAbs(tp - entry_price);
                if(tp_dist < sl_dist * InpTPFixedRR)
                    tp = 0.0;  // too close — fall through to fixed R:R
            }
        }

        // Step 2: Fixed R:R fallback
        if(tp == 0.0)
            tp = (direction == 1) ? entry_price + sl_dist * InpTPFixedRR
                                  : entry_price - sl_dist * InpTPFixedRR;

        // Enforce broker minimum
        double tp_dist = MathAbs(tp - entry_price);
        if(tp_dist < m_min_stop_pts)
            tp = (direction == 1) ? entry_price + m_min_stop_pts
                                  : entry_price - m_min_stop_pts;

        if(tp <= 0.0) return 0.0;
        return NormalizeDouble(tp, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    }

    // Compute the updated trailing SL for an open long position
    // Returns 0.0 if no improvement over current_sl
    double ComputeTrailLong(double current_price, double current_sl) const
    {
        double step   = InpTrailingStep * m_point;
        double new_sl = current_price - step;
        new_sl        = NormalizeDouble(new_sl,
                                        (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
        return (new_sl > current_sl + m_point) ? new_sl : 0.0;
    }

    // Compute the updated trailing SL for an open short position
    // Returns 0.0 if no improvement over current_sl
    double ComputeTrailShort(double current_price, double current_sl) const
    {
        double step   = InpTrailingStep * m_point;
        double new_sl = current_price + step;
        new_sl        = NormalizeDouble(new_sl,
                                        (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
        return (new_sl < current_sl - m_point) ? new_sl : 0.0;
    }
};
