//+------------------------------------------------------------------+
//| RegimeClassifier.mqh — APEX_SCALPER                              |
//| Classifies market regime on InpRegimeTF using:                  |
//|   1. ADX (computed from scratch — no IndicatorCreate)           |
//|   2. Bollinger Band width ratio                                 |
//|   3. VPOC std dev proxy (high/low midpoint per bar)            |
//| Updates g_CurrentRegime and g_RegimeString in State.mqh        |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| CRegimeClassifier                                                |
//+------------------------------------------------------------------+
class CRegimeClassifier
{
private:
    datetime m_last_regime_bar;  // last higher-TF bar when regime was computed

    //--- ADX helpers (all computed from OHLC arrays, no IndicatorCreate)

    // True Range for bar i relative to previous close
    double true_range(int i, const double &high[], const double &low[],
                      const double &close[], int n) const
    {
        if(i >= n - 1) return high[i] - low[i];
        double hl  = high[i]  - low[i];
        double hpc = MathAbs(high[i]  - close[i + 1]);
        double lpc = MathAbs(low[i]   - close[i + 1]);
        return MathMax(hl, MathMax(hpc, lpc));
    }

    // Wilder smoothing: smooth[0] = sum of first period values; then Wilder EMA
    void wilder_smooth(const double &raw[], double &smooth[], int period, int n) const
    {
        ArrayResize(smooth, n);
        ArrayInitialize(smooth, 0.0);
        if(n < period) return;

        // Seed with simple sum of oldest `period` bars
        double seed = 0.0;
        for(int i = n - period; i < n; i++) seed += raw[i];
        smooth[n - period] = seed;
        for(int i = n - period - 1; i >= 0; i--)
            smooth[i] = smooth[i + 1] - smooth[i + 1] / period + raw[i];
    }

    // Compute ADX over the last InpADXPeriod * 3 bars of InpRegimeTF
    double compute_adx() const
    {
        int    bars_needed = InpADXPeriod * 3 + 1;
        int    avail       = (int)SeriesInfoInteger(Symbol(), InpRegimeTF,
                                                    SERIES_BARS_COUNT);
        if(avail < bars_needed) return 20.0;  // neutral default

        double high[], low[], close[];
        // CopyHigh/CopyLow/CopyClose return newest-first; reverse to oldest-first
        if(CopyHigh( Symbol(), InpRegimeTF, 0, bars_needed, high)  < bars_needed) return 20.0;
        if(CopyLow(  Symbol(), InpRegimeTF, 0, bars_needed, low)   < bars_needed) return 20.0;
        if(CopyClose(Symbol(), InpRegimeTF, 0, bars_needed, close) < bars_needed) return 20.0;
        ArrayReverse(high); ArrayReverse(low); ArrayReverse(close);
        int n = bars_needed;

        // Compute raw DM+, DM-, TR arrays
        double dm_plus[], dm_minus[], tr[];
        ArrayResize(dm_plus,  n); ArrayResize(dm_minus, n); ArrayResize(tr, n);
        ArrayInitialize(dm_plus, 0.0); ArrayInitialize(dm_minus, 0.0);

        for(int i = 0; i < n - 1; i++)  // i = older bar (0=oldest), i+1 = newer
        {
            int cur = i + 1, prev = i;   // process bar cur vs bar prev
            double up   = high[cur]  - high[prev];
            double down = low[prev]  - low[cur];
            dm_plus[cur]  = (up > down && up > 0)   ? up   : 0.0;
            dm_minus[cur] = (down > up && down > 0) ? down : 0.0;
            tr[cur] = true_range(cur, high, low, close, n);
        }

        // Wilder smooth DM+, DM-, TR
        double s_plus[], s_minus[], s_tr[];
        wilder_smooth(dm_plus,  s_plus,  InpADXPeriod, n);
        wilder_smooth(dm_minus, s_minus, InpADXPeriod, n);
        wilder_smooth(tr,       s_tr,    InpADXPeriod, n);

        // DI+, DI- for newest available bar
        int    ref = InpADXPeriod;  // first valid smoothed index
        double di_plus  = (s_tr[ref] > 1e-10) ? 100.0 * s_plus[ref]  / s_tr[ref] : 0.0;
        double di_minus = (s_tr[ref] > 1e-10) ? 100.0 * s_minus[ref] / s_tr[ref] : 0.0;
        double dx       = (di_plus + di_minus > 1e-10)
                          ? 100.0 * MathAbs(di_plus - di_minus) / (di_plus + di_minus) : 0.0;

        // Wilder smooth DX array for ADX — build DX array first
        double dx_arr[];
        ArrayResize(dx_arr, n);
        ArrayInitialize(dx_arr, 0.0);
        for(int i = ref; i >= 0; i--)
        {
            double dip  = (s_tr[i] > 1e-10) ? 100.0 * s_plus[i]  / s_tr[i] : 0.0;
            double dim  = (s_tr[i] > 1e-10) ? 100.0 * s_minus[i] / s_tr[i] : 0.0;
            dx_arr[i]   = (dip + dim > 1e-10)
                          ? 100.0 * MathAbs(dip - dim) / (dip + dim) : 0.0;
        }
        double adx_arr[];
        wilder_smooth(dx_arr, adx_arr, InpADXPeriod, n);
        return adx_arr[0];  // most recent ADX
    }

    // Bollinger Band width ratio = (upper - lower) / middle
    double compute_bb_width() const
    {
        int bars_needed = InpADXPeriod * 2;
        double close[];
        if(CopyClose(Symbol(), InpRegimeTF, 0, bars_needed, close) < bars_needed)
            return InpBBWidthExpanding;  // neutral default
        double mean = RollingMean(close, bars_needed);
        double sd   = RollingStdDev(close, bars_needed, mean);
        if(mean < 1e-10) return 0.0;
        return (2.0 * 2.0 * sd) / mean;  // 2-sigma band width / midline
    }

    // VPOC std dev proxy: std dev of (high+low)/2 over InpVPOCStabilityBars
    double compute_vpoc_stddev() const
    {
        int n = InpVPOCStabilityBars + 1;
        double high[], low[];
        if(CopyHigh(Symbol(), InpRegimeTF, 0, n, high) < n) return 0.0;
        if(CopyLow( Symbol(), InpRegimeTF, 0, n, low)  < n) return 0.0;
        double mids[];
        ArrayResize(mids, InpVPOCStabilityBars);
        for(int i = 0; i < InpVPOCStabilityBars; i++)
            mids[i] = (high[i] + low[i]) * 0.5;
        double mean = RollingMean(mids, InpVPOCStabilityBars);
        return RollingStdDev(mids, InpVPOCStabilityBars, mean);
    }

    // Higher-TF delta proxy: count of up bars vs total bars
    int compute_htf_delta_sign() const
    {
        int n = InpADXPeriod;
        double open[], close[];
        if(CopyOpen( Symbol(), InpRegimeTF, 0, n, open)  < n) return 0;
        if(CopyClose(Symbol(), InpRegimeTF, 0, n, close) < n) return 0;
        int up = 0, dn = 0;
        for(int i = 0; i < n; i++)
            if(close[i] > open[i]) up++; else if(close[i] < open[i]) dn++;
        return (up > dn) ? 1 : (dn > up) ? -1 : 0;
    }

public:
    bool Initialize()
    {
        m_last_regime_bar = 0;
        return true;
    }

    // Call every tick; only recalculates when a new regime-TF bar closes
    void OnTick()
    {
        datetime current_bar = iTime(Symbol(), InpRegimeTF, 0);
        if(current_bar == 0 || current_bar == m_last_regime_bar) return;
        m_last_regime_bar = current_bar;
        Recalculate();
    }

    // Force a regime recalculation immediately
    void Recalculate()
    {
        double adx       = compute_adx();
        double bb_width  = compute_bb_width();
        double vpoc_sd   = compute_vpoc_stddev();
        int    htf_delta = compute_htf_delta_sign();

        ApexRegime prev = g_CurrentRegime;

        if(adx > InpADXTrendingThreshold &&
           bb_width > InpBBWidthExpanding &&
           vpoc_sd > InpVPOCMigrationTicks * SymbolInfoDouble(Symbol(), SYMBOL_POINT))
        {
            g_CurrentRegime = (htf_delta >= 0) ? REGIME_TRENDING_BULL : REGIME_TRENDING_BEAR;
        }
        else if(adx < InpADXRangingThreshold &&
                bb_width < InpBBWidthExpanding &&
                vpoc_sd < InpVPOCMigrationTicks * SymbolInfoDouble(Symbol(), SYMBOL_POINT))
        {
            g_CurrentRegime = REGIME_RANGING;
        }
        else if(bb_width > InpBBWidthExpanding * 3.0)
        {
            g_CurrentRegime = REGIME_HIGH_VOLATILITY;
        }
        else
        {
            g_CurrentRegime = REGIME_UNDEFINED;
        }

        g_RegimeString = RegimeToString(g_CurrentRegime);

        if(g_CurrentRegime != prev)
        {
            PrintFormat("APEX Regime changed: %s → %s (ADX:%.1f BB:%.4f SD:%.5f)",
                        RegimeToString(prev), g_RegimeString, adx, bb_width, vpoc_sd);
            g_EventBus.Publish(EVENT_REGIME_CHANGED);
        }
    }

    // Current regime (from global state)
    ApexRegime GetCurrentRegime() const { return g_CurrentRegime; }
};
