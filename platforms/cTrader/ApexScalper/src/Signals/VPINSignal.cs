using cAlgo.API;

namespace ApexScalper.Signals
{
    /// <summary>
    /// VPIN — Volume-bucketed flow toxicity / directional imbalance.
    /// MT5 reference: platforms/MT5/ApexScalper/Signals/VPINSignal.mqh
    /// TODO: bucket trades into fixed-volume bins (not time-based), classify each
    /// bucket as buy/sell using bulk volume classification (BVC), compute toxicity
    /// = |buyVol - sellVol| / totalVol over rolling N buckets.
    /// </summary>
    public class VPINSignal : SignalBase
    {
        public VPINSignal(Robot bot) : base(bot) { }
        public override string Name => "VPIN";

        public override void Update()
        {
            // STUB — see TODO.
            Score = 0.0;
            IsFresh = true;
        }
    }
}
