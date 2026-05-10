using cAlgo.API;

namespace ApexScalper.Signals
{
    /// <summary>
    /// Order Book Imbalance (Shallow) — top-3 levels with spoof detection.
    /// MT5 reference: platforms/MT5/ApexScalper/Signals/OBISignal.mqh (shallow mode)
    /// cTrader API: Symbol.MarketDepth, Symbol.MarketDepth.Updated event,
    /// Symbol.MarketDepth.Entries (PriceVolume[] of bid/ask levels).
    /// TODO: weight top-3 bid/ask volumes, compute (sumBids - sumAsks)/(sumBids+sumAsks),
    /// flag spoof when a deep level vanishes within N ticks of appearing.
    /// </summary>
    public class OBIShallowSignal : SignalBase
    {
        public OBIShallowSignal(Robot bot) : base(bot) { }
        public override string Name => "OBIShallow";

        public override void Update()
        {
            // STUB — needs Symbol.MarketDepth subscription
            Score = 0.0;
            IsFresh = true;
        }
    }
}
