using System.Collections.Generic;
using System.Linq;
using ApexScalper.Signals;

namespace ApexScalper.Engine
{
    /// <summary>
    /// Composite weighted score across all fresh signals.
    /// MT5 reference: platforms/MT5/ApexScalper/Engine/ScoringEngine.mqh
    /// </summary>
    public class ScoringEngine
    {
        private readonly IReadOnlyList<ISignal> _signals;

        public ScoringEngine(IReadOnlyList<ISignal> signals)
        {
            _signals = signals;
        }

        /// <summary>Σ (weight_i × score_i) across fresh signals only.</summary>
        public double Composite()
        {
            double sum = 0;
            double totalWeight = 0;
            foreach (var s in _signals)
            {
                if (!s.IsFresh) continue;
                sum += s.Weight * s.Score;
                totalWeight += s.Weight;
            }
            // Re-normalize so dropped (stale) signals don't dilute the score.
            if (totalWeight <= 0) return 0;
            return sum / totalWeight * Sum(_signals.Select(s => s.Weight));
        }

        /// <summary>
        /// Number of fresh signals whose direction agrees with the composite sign
        /// (or all if composite ~= 0).
        /// </summary>
        public int AgreeingCount(double composite)
        {
            int sign = composite > 0 ? 1 : (composite < 0 ? -1 : 0);
            if (sign == 0) return 0;
            return _signals.Count(s => s.IsFresh
                                       && ((sign > 0 && s.Score > 0)
                                        || (sign < 0 && s.Score < 0)));
        }

        private static double Sum(IEnumerable<double> values)
        {
            double total = 0;
            foreach (var v in values) total += v;
            return total;
        }
    }
}
