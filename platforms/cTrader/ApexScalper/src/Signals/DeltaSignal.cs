using cAlgo.API;

namespace ApexScalper.Signals
{
    /// <summary>
    /// Cumulative tick delta — Z-scored, with acceleration and divergence detection.
    /// MT5 reference: platforms/MT5/ApexScalper/Signals/DeltaSignal.mqh
    /// TODO: implement Z-score over rolling window of bar deltas; detect divergence
    /// (price-high vs delta-high disagreement); detect acceleration via second
    /// difference of cumulative delta.
    /// </summary>
    public class DeltaSignal : SignalBase
    {
        public DeltaSignal(Robot bot) : base(bot) { }
        public override string Name => "CumulativeDelta";

        public override void Update()
        {
            // STUB — see TODO in class doc-comment.
            Score = 0.0;
            IsFresh = true;
        }
    }
}
