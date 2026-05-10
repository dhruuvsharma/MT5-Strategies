using cAlgo.API;

namespace ApexScalper.Signals
{
    /// <summary>
    /// Common interface for all 8 order-flow signals. Each signal's Evaluate()
    /// returns a continuous score in [-3.0, +3.0]:
    ///   -3.0 = maximum bearish conviction
    ///    0.0 = neutral / not actionable
    ///   +3.0 = maximum bullish conviction
    /// </summary>
    public interface ISignal
    {
        string Name { get; }
        double Weight { get; set; }
        double Score { get; }     // last-computed score
        bool   IsFresh { get; }   // false if signal has decayed past TTL
        void   Update();          // recompute Score from current market state
    }

    public abstract class SignalBase : ISignal
    {
        protected readonly Robot Bot;
        protected SignalBase(Robot bot) { Bot = bot; }

        public abstract string Name { get; }
        public double Weight { get; set; }
        public double Score { get; protected set; }
        public bool   IsFresh { get; protected set; } = true;

        public abstract void Update();
    }
}
