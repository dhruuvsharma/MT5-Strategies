using cAlgo.API;

namespace ApexScalper.Signals
{
    /// <summary>
    /// Order Book Imbalance (Deep) — top-10 levels with exponential weighting.
    /// MT5 reference: platforms/MT5/ApexScalper/Signals/OBISignal.mqh (deep mode)
    /// TODO: same as Shallow but with exp(-k*level) weighting; less sensitive to
    /// shallow noise, more sensitive to institutional resting liquidity.
    /// </summary>
    public class OBIDeepSignal : SignalBase
    {
        public OBIDeepSignal(Robot bot) : base(bot) { }
        public override string Name => "OBIDeep";

        public override void Update()
        {
            // STUB
            Score = 0.0;
            IsFresh = true;
        }
    }
}
