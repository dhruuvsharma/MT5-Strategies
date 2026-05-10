using cAlgo.API;

namespace ApexScalper.Signals
{
    /// <summary>
    /// Tape speed — trade arrival rate Z-score with directional fraction filter.
    /// MT5 reference: platforms/MT5/ApexScalper/Signals/TapeSpeedSignal.mqh
    /// TODO: count ticks per fixed window (e.g. 5 sec rolling), Z-score over
    /// recent N windows; gate by directional fraction (uptick/total > 0.6 → bull).
    /// </summary>
    public class TapeSpeedSignal : SignalBase
    {
        public TapeSpeedSignal(Robot bot) : base(bot) { }
        public override string Name => "TapeSpeed";

        public override void Update()
        {
            // STUB
            Score = 0.0;
            IsFresh = true;
        }
    }
}
