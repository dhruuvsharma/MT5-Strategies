//+------------------------------------------------------------------+
//| MathUtils.mqh — APEX_SCALPER                                     |
//| Standalone math functions. No class wrapper.                     |
//| All formulas match MATH REFERENCE section of master spec.       |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| RollingMean — arithmetic mean of the first `count` elements     |
//+------------------------------------------------------------------+
double RollingMean(const double &arr[], int count)
{
    if(count <= 0) return 0.0;
    double sum = 0.0;
    for(int i = 0; i < count; i++)
        sum += arr[i];
    return sum / count;
}

//+------------------------------------------------------------------+
//| RollingStdDev — population std dev given pre-computed mean      |
//+------------------------------------------------------------------+
double RollingStdDev(const double &arr[], int count, double mean)
{
    if(count <= 1) return 0.0;
    double variance = 0.0;
    for(int i = 0; i < count; i++)
    {
        double diff = arr[i] - mean;
        variance += diff * diff;
    }
    return MathSqrt(variance / count);
}

//+------------------------------------------------------------------+
//| ZScore — standard score; returns 0 if stddev is effectively 0   |
//+------------------------------------------------------------------+
double ZScore(double value, double mean, double stddev)
{
    if(stddev < 1e-10) return 0.0;
    return (value - mean) / stddev;
}

//+------------------------------------------------------------------+
//| LinearRegressionSlope — OLS slope for (x[i], y[i]) pairs       |
//+------------------------------------------------------------------+
double LinearRegressionSlope(const double &x[], const double &y[], int count)
{
    if(count < 2) return 0.0;
    double sum_x = 0, sum_y = 0, sum_xx = 0, sum_xy = 0;
    for(int i = 0; i < count; i++)
    {
        sum_x  += x[i];
        sum_y  += y[i];
        sum_xx += x[i] * x[i];
        sum_xy += x[i] * y[i];
    }
    double denom = count * sum_xx - sum_x * sum_x;
    if(MathAbs(denom) < 1e-10) return 0.0;
    return (count * sum_xy - sum_x * sum_y) / denom;
}

//+------------------------------------------------------------------+
//| LinearRegressionSlope (weighted) — per master spec math ref     |
//+------------------------------------------------------------------+
double LinearRegressionSlopeWeighted(const double &x[], const double &y[],
                                      const double &w[], int count)
{
    if(count < 2) return 0.0;
    double S_w   = 0, S_wx  = 0, S_wy  = 0;
    double S_wxx = 0, S_wxy = 0;
    for(int i = 0; i < count; i++)
    {
        S_w   += w[i];
        S_wx  += w[i] * x[i];
        S_wy  += w[i] * y[i];
        S_wxx += w[i] * x[i] * x[i];
        S_wxy += w[i] * x[i] * y[i];
    }
    double denom = S_w * S_wxx - S_wx * S_wx;
    if(MathAbs(denom) < 1e-10) return 0.0;
    return (S_w * S_wxy - S_wx * S_wy) / denom;
}

//+------------------------------------------------------------------+
//| LinearRegressionR2 — coefficient of determination (0–1)        |
//+------------------------------------------------------------------+
double LinearRegressionR2(const double &x[], const double &y[], int count)
{
    if(count < 2) return 0.0;
    double slope     = LinearRegressionSlope(x, y, count);
    double mean_x    = 0, mean_y = 0;
    for(int i = 0; i < count; i++) { mean_x += x[i]; mean_y += y[i]; }
    mean_x /= count;
    mean_y /= count;
    double intercept = mean_y - slope * mean_x;

    double ss_res = 0, ss_tot = 0;
    for(int i = 0; i < count; i++)
    {
        double predicted = slope * x[i] + intercept;
        double residual  = y[i] - predicted;
        ss_res += residual  * residual;
        ss_tot += (y[i] - mean_y) * (y[i] - mean_y);
    }
    if(ss_tot < 1e-10) return 0.0;
    return 1.0 - (ss_res / ss_tot);
}

//+------------------------------------------------------------------+
//| ExponentialDecayWeight — decay^level (0-based level)           |
//+------------------------------------------------------------------+
double ExponentialDecayWeight(int level, double decay)
{
    if(decay <= 0.0 || decay >= 1.0) return (level == 0) ? 1.0 : 0.0;
    return MathPow(decay, level);
}

//+------------------------------------------------------------------+
//| Normalize — map value from [min_val, max_val] to [out_min, out_max] |
//+------------------------------------------------------------------+
double Normalize(double value, double min_val, double max_val,
                 double out_min, double out_max)
{
    double range = max_val - min_val;
    if(MathAbs(range) < 1e-10) return (out_min + out_max) * 0.5;
    double t = (value - min_val) / range;
    return out_min + t * (out_max - out_min);
}

//+------------------------------------------------------------------+
//| Clamp — constrain value to [min_val, max_val]                   |
//+------------------------------------------------------------------+
double Clamp(double value, double min_val, double max_val)
{
    if(value < min_val) return min_val;
    if(value > max_val) return max_val;
    return value;
}

//+------------------------------------------------------------------+
//| IsOutlier — true if |value - mean| > threshold * stddev        |
//+------------------------------------------------------------------+
bool IsOutlier(double value, double mean, double stddev, double threshold)
{
    if(stddev < 1e-10) return false;
    return MathAbs(value - mean) > threshold * stddev;
}

//+------------------------------------------------------------------+
//| VWAP — volume-weighted average price                            |
//+------------------------------------------------------------------+
double VWAP(const double &prices[], const long &volumes[], int count)
{
    if(count <= 0) return 0.0;
    double num = 0.0;
    long   den = 0;
    for(int i = 0; i < count; i++)
    {
        num += prices[i] * volumes[i];
        den += volumes[i];
    }
    if(den == 0) return 0.0;
    return num / den;
}

//+------------------------------------------------------------------+
//| WeightedMean — weighted arithmetic mean                         |
//+------------------------------------------------------------------+
double WeightedMean(const double &values[], const double &weights[], int count)
{
    if(count <= 0) return 0.0;
    double num = 0.0, den = 0.0;
    for(int i = 0; i < count; i++)
    {
        num += values[i] * weights[i];
        den += weights[i];
    }
    if(MathAbs(den) < 1e-10) return 0.0;
    return num / den;
}

//+------------------------------------------------------------------+
//| ScoreFromZScore — maps z-score to signal score [-3, +3]        |
//| Convenience wrapper used by multiple signal modules             |
//+------------------------------------------------------------------+
double ScoreFromZScore(double zscore, double threshold)
{
    if(threshold < 1e-10) return 0.0;
    return Clamp(zscore / threshold * 3.0, -3.0, 3.0);
}

//+------------------------------------------------------------------+
//| OBIFormula — order book imbalance for N levels                 |
//| Returns -1.0 to +1.0; positive = bid-heavy                     |
//+------------------------------------------------------------------+
double OBIFormula(const long &bid_vols[], const long &ask_vols[], int levels)
{
    long sum_bid = 0, sum_ask = 0;
    for(int i = 0; i < levels; i++)
    {
        sum_bid += bid_vols[i];
        sum_ask += ask_vols[i];
    }
    long total = sum_bid + sum_ask;
    if(total == 0) return 0.0;
    return (double)(sum_bid - sum_ask) / (double)total;
}

//+------------------------------------------------------------------+
//| WeightedOBI — exponentially decayed OBI across levels          |
//+------------------------------------------------------------------+
double WeightedOBI(const long &bid_vols[], const long &ask_vols[],
                   int levels, double decay)
{
    double num = 0.0, den = 0.0;
    for(int i = 0; i < levels; i++)
    {
        double w  = ExponentialDecayWeight(i, decay);
        num += w * (bid_vols[i] - ask_vols[i]);
        den += w * (bid_vols[i] + ask_vols[i]);
    }
    if(MathAbs(den) < 1e-10) return 0.0;
    return num / den;
}

//+------------------------------------------------------------------+
//| UNIT TEST — call from OnInit in debug builds to verify math     |
//+------------------------------------------------------------------+
bool MathUtils_RunTests()
{
    bool ok = true;
    double arr[] = {1.0, 2.0, 3.0, 4.0, 5.0};

    // RollingMean
    double m = RollingMean(arr, 5);
    if(MathAbs(m - 3.0) > 1e-9) { Print("FAIL RollingMean: ", m); ok = false; }

    // RollingStdDev (population)
    double sd = RollingStdDev(arr, 5, m);
    if(MathAbs(sd - MathSqrt(2.0)) > 1e-9) { Print("FAIL RollingStdDev: ", sd); ok = false; }

    // ZScore
    double z = ZScore(5.0, 3.0, MathSqrt(2.0));
    if(MathAbs(z - (2.0 / MathSqrt(2.0))) > 1e-9) { Print("FAIL ZScore: ", z); ok = false; }

    // Clamp
    if(Clamp(5.0, -3.0, 3.0) != 3.0)  { Print("FAIL Clamp high"); ok = false; }
    if(Clamp(-5.0, -3.0, 3.0) != -3.0) { Print("FAIL Clamp low"); ok = false; }
    if(Clamp(1.0, -3.0, 3.0) != 1.0)   { Print("FAIL Clamp mid"); ok = false; }

    // ExponentialDecayWeight
    double w0 = ExponentialDecayWeight(0, 0.5);
    double w1 = ExponentialDecayWeight(1, 0.5);
    double w2 = ExponentialDecayWeight(2, 0.5);
    if(MathAbs(w0 - 1.0) > 1e-9)  { Print("FAIL Decay w0: ", w0); ok = false; }
    if(MathAbs(w1 - 0.5) > 1e-9)  { Print("FAIL Decay w1: ", w1); ok = false; }
    if(MathAbs(w2 - 0.25) > 1e-9) { Print("FAIL Decay w2: ", w2); ok = false; }

    // LinearRegressionSlope: y = 2x → slope should be 2
    double xs[] = {0.0, 1.0, 2.0, 3.0, 4.0};
    double ys[] = {0.0, 2.0, 4.0, 6.0, 8.0};
    double slope = LinearRegressionSlope(xs, ys, 5);
    if(MathAbs(slope - 2.0) > 1e-9) { Print("FAIL LinRegSlope: ", slope); ok = false; }

    // R²: perfect line → R² = 1.0
    double r2 = LinearRegressionR2(xs, ys, 5);
    if(MathAbs(r2 - 1.0) > 1e-9) { Print("FAIL R2: ", r2); ok = false; }

    // Normalize
    double n = Normalize(5.0, 0.0, 10.0, -1.0, 1.0);
    if(MathAbs(n - 0.0) > 1e-9) { Print("FAIL Normalize: ", n); ok = false; }

    // VWAP
    double prices[] = {100.0, 200.0};
    long   vols[]   = {1, 1};
    double vwap = VWAP(prices, vols, 2);
    if(MathAbs(vwap - 150.0) > 1e-9) { Print("FAIL VWAP: ", vwap); ok = false; }

    // OBIFormula: equal volume → 0
    long bids[] = {100, 100};
    long asks[] = {100, 100};
    double obi = OBIFormula(bids, asks, 2);
    if(MathAbs(obi) > 1e-9) { Print("FAIL OBI equal: ", obi); ok = false; }

    if(ok) Print("MathUtils: all tests PASSED");
    return ok;
}
