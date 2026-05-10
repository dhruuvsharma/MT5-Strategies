using cAlgo.API;

namespace ApexScalper.Engine
{
    public enum Regime { Unknown, TrendingBull, TrendingBear, Ranging, HighVolatility }

    /// <summary>
    /// Classifies market regime from HTF ADX + Bollinger Band width + VPOC stability.
    /// MT5 reference: platforms/MT5/ApexScalper/Engine/RegimeClassifier.mqh
    /// TODO: compute regime, return weight multiplier from regime → signal map.
    /// Trending: boost Delta/HVP. Ranging: boost OBI/Absorption. HighVol: ×0.5 all.
    /// </summary>
    public class RegimeClassifier
    {
        private readonly Robot _bot;
        public Regime Current { get; private set; } = Regime.Unknown;

        public RegimeClassifier(Robot bot) { _bot = bot; }

        public double WeightMultiplier(double composite)
        {
            // STUB — passthrough until full classifier is implemented.
            return 1.0;
        }
    }
}
