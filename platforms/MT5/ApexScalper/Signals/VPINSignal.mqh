//+------------------------------------------------------------------+
//| VPINSignal.mqh — APEX_SCALPER                                    |
//| Volume-bucketed VPIN flow toxicity estimator.                   |
//| Accumulates ticks into fixed-volume buckets, computes rolling   |
//| mean of |buy_fraction - 0.5| * 2 over last L buckets.          |
//+------------------------------------------------------------------+

#include "SignalBase.mqh"
#include "../Core/Inputs.mqh"
#include "../Utils/RingBuffer.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Data/TickCollector.mqh"

//--- Internal bucket struct
struct VPINBucket
{
    long   buy_vol;
    long   sell_vol;
    long   total_vol;
    double buy_fraction;
    double toxicity;     // |buy_fraction - 0.5| * 2
};

class CVPINSignal : public CSignalBase
{
private:
    CTickCollector          *m_tc;
    CRingBuffer<VPINBucket>  m_buckets;

    // Accumulator for the bucket currently being filled
    long   m_accum_buy;
    long   m_accum_sell;
    long   m_accum_total;
    long   m_last_tick_index;  // track which ticks we've consumed

    // Build completed buckets from new ticks since last call
    void consume_ticks()
    {
        ApexTick ticks[];
        int n = m_tc.GetLastN(APEX_MAX_TICK_BUFFER, ticks);

        // Find ticks newer than m_last_tick_index
        int start = n - 1; // oldest first
        for(int i = n - 1; i >= 0; i--)
            if(ticks[i].index > m_last_tick_index) start = i;
            else break;

        for(int i = start; i >= 0; i--)
        {
            ApexTick t = ticks[i];
            if(t.index <= m_last_tick_index) continue;
            m_last_tick_index = t.index;

            long vol = (t.volume > 0) ? t.volume : 1;
            m_accum_total += vol;
            if(t.direction ==  1) m_accum_buy  += vol;
            if(t.direction == -1) m_accum_sell += vol;

            // Bucket complete when accumulated volume >= threshold
            if(m_accum_total >= InpVPINBucketVolume)
            {
                VPINBucket b;
                b.buy_vol      = m_accum_buy;
                b.sell_vol     = m_accum_sell;
                b.total_vol    = m_accum_total;
                b.buy_fraction = (m_accum_total > 0)
                                 ? (double)m_accum_buy / m_accum_total : 0.5;
                b.toxicity     = MathAbs(b.buy_fraction - 0.5) * 2.0;
                m_buckets.Push(b);

                // Reset accumulator
                m_accum_buy   = 0;
                m_accum_sell  = 0;
                m_accum_total = 0;
            }
        }
    }

    // Compute VPIN from the last L completed buckets
    double compute_vpin(int &bucket_count_out) const
    {
        int n = MathMin(InpVPINLookbackBuckets, m_buckets.Size());
        bucket_count_out = n;
        if(n == 0) return 0.0;
        double sum = 0.0;
        VPINBucket _b;
        for(int i = 0; i < n; i++) { m_buckets.Get(i, _b); sum += _b.toxicity; }
        return sum / n;
    }

    // True if VPIN is rising over the last 3 buckets
    bool is_vpin_rising() const
    {
        if(m_buckets.Size() < 3) return false;
        VPINBucket _b0, _b2;
        m_buckets.Get(0, _b0);
        m_buckets.Get(2, _b2);
        return _b0.toxicity > _b2.toxicity;
    }

public:
    bool Initialize(CTickCollector *tc)
    {
        if(tc == NULL) return false;
        m_tc             = tc;
        m_accum_buy      = 0;
        m_accum_sell     = 0;
        m_accum_total    = 0;
        m_last_tick_index = -1;
        return m_buckets.Initialize(APEX_MAX_VPIN_BUCKETS);
    }

    // Call every tick to keep buckets up to date
    void OnTick() { if(m_tc != NULL && m_tc.IsReady()) consume_ticks(); }

    virtual SignalResult Calculate() override
    {
        SignalResult r;
        if(!IsReady()) { invalid_result(r, Name(), "insufficient buckets"); return r; }

        int n_buckets = 0;
        double vpin   = compute_vpin(n_buckets);
        if(n_buckets < 2) { invalid_result(r, Name(), "not enough buckets"); return r; }

        // Direction from the most recently completed bucket
        VPINBucket latest;
        m_buckets.Get(0, latest);
        bool buy_heavy = latest.buy_fraction > 0.5;
        bool rising    = is_vpin_rising();

        double score = 0.0;
        double conf  = Clamp(vpin, 0.0, 1.0);

        if(vpin >= InpVPINThreshold)
        {
            double excess = (vpin - InpVPINThreshold) / (1.0 - InpVPINThreshold);
            double base   = 2.5 + excess * 0.5;  // 2.5 to 3.0
            score = buy_heavy ? base : -base;
            if(rising) score += (score > 0) ? 0.3 : -0.3;
        }
        else
        {
            // Below threshold: proportional, capped at ±1.5
            double prop = Clamp(vpin / InpVPINThreshold * 1.5, 0.0, 1.5);
            score = buy_heavy ? prop : -prop;
            if(rising) score += (score > 0) ? 0.3 : -0.3;
        }
        score = Clamp(score, APEX_SCORE_MIN, APEX_SCORE_MAX);

        string note = StringFormat("VPIN:%.3f thresh:%.2f buy_frac:%.2f rising:%s",
                                   vpin, InpVPINThreshold,
                                   latest.buy_fraction, rising ? "Y" : "N");
        make_result(r, Name(), score, conf, note);
        return r;
    }

    virtual string  Name()    override { return "VPIN";        }
    virtual double  Weight()  override { return InpWeightVPIN; }
    virtual bool    IsReady() override
    {
        return m_tc != NULL && m_tc.IsReady()
               && m_buckets.Size() >= MathMin(2, InpVPINLookbackBuckets);
    }
};
