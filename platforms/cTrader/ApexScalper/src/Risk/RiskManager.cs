using cAlgo.API;
using cAlgo.API.Internals;

namespace ApexScalper.Risk
{
    /// <summary>
    /// Spread / session / daily-loss / cooldown gates before entry.
    /// MT5 reference: platforms/MT5/ApexScalper/Risk/RiskManager.mqh + SessionFilter / SpreadFilter.
    /// TODO: implement daily-loss circuit breaker, peak-equity drawdown breaker,
    /// max-open-positions cap, min-bars cooldown, session toggles.
    /// </summary>
    public class RiskManager
    {
        private readonly Robot _bot;
        public double RiskPercent { get; set; }
        public int MaxSpreadPoints { get; set; }

        public RiskManager(Robot bot) { _bot = bot; }

        public bool AllowEntry(out string reason)
        {
            reason = "OK";
            // Spread hard gate (the only filter active in the scaffold)
            int spreadPts = (int)System.Math.Round(_bot.Symbol.Spread / _bot.Symbol.TickSize);
            if (spreadPts > MaxSpreadPoints)
            {
                reason = "SPREAD HIGH (" + spreadPts + ">" + MaxSpreadPoints + ")";
                return false;
            }
            return true;
        }
    }
}
