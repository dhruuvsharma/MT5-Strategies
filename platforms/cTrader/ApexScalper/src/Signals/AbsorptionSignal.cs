using cAlgo.API;

namespace ApexScalper.Signals
{
    /// <summary>
    /// Absorption — high volume per unit price range, indicating one side
    /// of the book is absorbing aggressive flow without price movement.
    /// MT5 reference: platforms/MT5/ApexScalper/Signals/AbsorptionSignal.mqh
    /// TODO: compute volume / range per bar, Z-score over rolling window;
    /// sign by direction of absorbing side (buyers absorb sells = bullish).
    /// </summary>
    public class AbsorptionSignal : SignalBase
    {
        public AbsorptionSignal(Robot bot) : base(bot) { }
        public override string Name => "Absorption";

        public override void Update()
        {
            // STUB
            Score = 0.0;
            IsFresh = true;
        }
    }
}
