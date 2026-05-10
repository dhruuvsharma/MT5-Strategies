using cAlgo.API;

namespace ApexScalper.Signals
{
    /// <summary>
    /// HVP regression slope — weighted linear regression through high-volume-pocket nodes.
    /// MT5 reference: platforms/MT5/ApexScalper/Signals/HVPSignal.mqh
    /// TODO: identify HVP nodes (local volume maxima in volume profile); fit
    /// weighted linear regression price-vs-time through them; sign + magnitude
    /// of slope is the signal.
    /// </summary>
    public class HVPSlopeSignal : SignalBase
    {
        public HVPSlopeSignal(Robot bot) : base(bot) { }
        public override string Name => "HVPSlope";

        public override void Update()
        {
            // STUB — needs VolumeProfile builder
            Score = 0.0;
            IsFresh = true;
        }
    }
}
