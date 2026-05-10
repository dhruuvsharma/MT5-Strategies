using System.Collections.Generic;
using System.Linq;
using ApexScalper.Signals;

namespace ApexScalper.Engine
{
    /// <summary>
    /// Blocks trades when the two highest-weight signals disagree near the threshold.
    /// MT5 reference: platforms/MT5/ApexScalper/Engine/ConflictFilter.mqh
    /// </summary>
    public class ConflictFilter
    {
        public bool HasConflict(IReadOnlyList<ISignal> signals, double composite, double threshold)
        {
            // Top-2 by weight from the fresh set
            var top2 = signals.Where(s => s.IsFresh)
                              .OrderByDescending(s => s.Weight)
                              .Take(2)
                              .ToList();
            if (top2.Count < 2) return false;

            // Conflict when their score signs disagree AND |composite| is near the threshold
            int s1 = System.Math.Sign(top2[0].Score);
            int s2 = System.Math.Sign(top2[1].Score);
            if (s1 == 0 || s2 == 0 || s1 == s2) return false;

            // "Near threshold" — within 30% of threshold band
            return System.Math.Abs(composite) < threshold * 1.3;
        }
    }
}
