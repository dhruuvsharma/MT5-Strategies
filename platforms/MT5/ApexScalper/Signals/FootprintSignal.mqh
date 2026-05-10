//+------------------------------------------------------------------+
//| FootprintSignal.mqh — APEX_SCALPER                               |
//| Stacked imbalance detection across last 3 footprint candles.   |
//| Bonus for building imbalance in current (live) candle.         |
//| Fill-target sub-signal when price approaches a stacked zone.   |
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/WindowManager.mqh"

class CFootprintSignal : public CSignalBase
{
private:
    CWindowManager *m_wm;

    // Score from a single footprint candle's stacked counts
    double score_from_candle(const FootprintCandle &fc) const
    {
        double bull = 0.0, bear = 0.0;
        int    min  = InpMinStackedRows;
        if(fc.stacked_bull_imbalance >= min)
            bull = Clamp((double)(fc.stacked_bull_imbalance - min + 1), 0.0, 3.0);
        if(fc.stacked_bear_imbalance >= min)
            bear = Clamp((double)(fc.stacked_bear_imbalance - min + 1), 0.0, 3.0);
        return bull - bear;  // positive = bullish, negative = bearish
    }

    // Fill-target sub-signal: approaching a stacked imbalance level
    double fill_target_score(const FootprintCandle &fps[], int n,
                             double current_price) const
    {
        double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        double score = 0.0;

        for(int c = 0; c < n && c < 3; c++)
        {
            // Find the stacked imbalance zone price (rows near the imbalance cluster)
            for(int r = 0; r < fps[c].row_count; r++)
            {
                if(fps[c].rows[r].ask_imbalance || fps[c].rows[r].zero_bid)
                {
                    // Bullish zone: if price approaching from above → fill up
                    double zone = fps[c].rows[r].price;
                    double dist = current_price - zone;
                    if(dist > 0 && dist < point * 20)
                    {
                        score += 0.5;
                        break;
                    }
                }
                if(fps[c].rows[r].bid_imbalance || fps[c].rows[r].zero_ask)
                {
                    // Bearish zone: price approaching from below → fill down
                    double zone = fps[c].rows[r].price;
                    double dist = zone - current_price;
                    if(dist > 0 && dist < point * 20)
                    {
                        score -= 0.5;
                        break;
                    }
                }
            }
        }
        return Clamp(score, -1.0, 1.0);
    }

public:
    bool Initialize(CWindowManager *wm)
    {
        if(wm == NULL) return false;
        m_wm = wm;
        return true;
    }

    virtual SignalResult Calculate() override
    {
        SignalResult r;
        if(!IsReady()) { invalid_result(r, Name(), "window not ready"); return r; }

        FootprintCandle fps[];
        int n = m_wm.GetFootprints(fps);
        int check = MathMin(n, 3);
        if(check == 0) { invalid_result(r, Name(), "no footprint data"); return r; }

        // Score from last 3 complete candles
        double score = 0.0;
        for(int i = 0; i < check; i++)
            score += score_from_candle(fps[i]);
        score = Clamp(score / check, APEX_SCORE_MIN, APEX_SCORE_MAX);

        // Bonus: live candle building imbalance (one less than threshold)
        FootprintCandle live = m_wm.GetCurrentFootprint();
        if(live.stacked_bull_imbalance >= InpMinStackedRows - 1 && score >= 0)
            score = Clamp(score + 0.5, APEX_SCORE_MIN, APEX_SCORE_MAX);
        if(live.stacked_bear_imbalance >= InpMinStackedRows - 1 && score <= 0)
            score = Clamp(score - 0.5, APEX_SCORE_MIN, APEX_SCORE_MAX);

        // Fill-target bonus
        MqlTick tick;
        SymbolInfoTick(Symbol(), tick);
        double cur_price = (tick.bid + tick.ask) * 0.5;
        score += fill_target_score(fps, check, cur_price);
        score  = Clamp(score, APEX_SCORE_MIN, APEX_SCORE_MAX);

        double conf = MathAbs(score) / 3.0;

        string note = StringFormat("bull_stack:%d bear_stack:%d live_bull:%d live_bear:%d",
                                   fps[0].stacked_bull_imbalance,
                                   fps[0].stacked_bear_imbalance,
                                   live.stacked_bull_imbalance,
                                   live.stacked_bear_imbalance);
        make_result(r, Name(), score, conf, note);
        return r;
    }

    virtual string  Name()    override { return "FOOTPRINT";        }
    virtual double  Weight()  override { return InpWeightFootprint;  }
    virtual bool    IsReady() override
    {
        return m_wm != NULL && m_wm.FootprintCount() >= 3;
    }
};
