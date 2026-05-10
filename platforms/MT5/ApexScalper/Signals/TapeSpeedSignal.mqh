//+------------------------------------------------------------------+
//| TapeSpeedSignal.mqh — APEX_SCALPER                               |
//| Trade arrival rate Z-score + directional bias.                  |
//| Spike with directional bias = informed flow.                    |
//| Spike with neutral fraction = institutional algo (score 0).    |
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/RingBuffer.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/TickCollector.mqh"

#define TAPE_SPEED_HISTORY_SIZE 60

class CTapeSpeedSignal : public CSignalBase
{
private:
    CTickCollector           *m_tc;
    CRingBuffer<double>       m_speed_history;   // rolling tape speed observations

public:
    bool Initialize(CTickCollector *tc)
    {
        if(tc == NULL) return false;
        m_tc = tc;
        return m_speed_history.Initialize(TAPE_SPEED_HISTORY_SIZE);
    }

    // Call every tick to maintain the rolling speed history
    void OnTick()
    {
        if(m_tc == NULL || !m_tc.IsReady()) return;
        double speed = m_tc.GetTapeSpeed(InpTapeSpeedWindow);
        m_speed_history.Push(speed);
    }

    virtual SignalResult Calculate() override
    {
        SignalResult r;
        if(!IsReady()) { invalid_result(r, Name(), "insufficient history"); return r; }

        double cur_speed = m_tc.GetTapeSpeed(InpTapeSpeedWindow);
        double dir_frac  = m_tc.GetDirectionalFraction(InpTapeSpeedWindow);

        // Build speed array for rolling stats
        double speeds[];
        int n = m_speed_history.ToArray(speeds);
        double mean = RollingMean(speeds, n);
        double sd   = RollingStdDev(speeds, n, mean);
        double z    = ZScore(cur_speed, mean, sd);

        double score = 0.0;
        double conf  = Clamp(MathAbs(z) / (InpTapeSpeedZScore * 2.0), 0.0, 1.0);

        if(z > InpTapeSpeedZScore)
        {
            // Speed spike detected — classify by direction
            if(dir_frac > InpTapeSpeedDirectional)
            {
                // Buy-heavy directional spike
                score = ScoreFromZScore(z, InpTapeSpeedZScore);
            }
            else if(dir_frac < (1.0 - InpTapeSpeedDirectional))
            {
                // Sell-heavy directional spike
                score = -ScoreFromZScore(z, InpTapeSpeedZScore);
            }
            else
            {
                // Neutral fraction: institutional algo, uncertain
                score = 0.0;
                conf  = 0.1;
            }
        }
        // No spike: score stays 0

        string note = StringFormat("speed:%.1f/s z:%.2f dir_frac:%.2f mean:%.1f",
                                   cur_speed, z, dir_frac, mean);
        make_result(r, Name(), score, conf, note);
        return r;
    }

    virtual string  Name()    override { return "TAPE_SPEED";        }
    virtual double  Weight()  override { return InpWeightTapeSpeed;  }
    virtual bool    IsReady() override
    {
        return m_tc != NULL && m_tc.IsReady() && m_speed_history.Size() >= 30;
    }
};
