using cAlgo.API;
using cAlgo.API.Internals;

namespace ApexScalper.Execution
{
    /// <summary>
    /// Order placement + SL/TP anchored to HVP / stacked-imbalance levels.
    /// MT5 reference: platforms/MT5/ApexScalper/Execution/TradeManager.mqh
    ///                + StopLossEngine.mqh + TakeProfitEngine.mqh.
    /// TODO: anchor SL behind nearest HVP node or stacked-imbalance level with
    /// configurable buffer; TP at opposing HVP; trailing activation after first TP.
    /// Currently the scaffold's OpenPosition is a no-op so the WIP cBot doesn't
    /// place trades.
    /// </summary>
    public class TradeManager
    {
        private readonly Robot _bot;
        public string Label { get; set; } = "ApexScalper";

        public TradeManager(Robot bot) { _bot = bot; }

        public void OpenPosition(int direction)
        {
            // STUB — no trades placed in the scaffold.
            // When implementing, use _bot.ExecuteMarketOrder(...) with SL/TP
            // anchored to HVP nodes per the MT5 reference.
            _bot.Print("[ApexScalper-cT-WIP] OpenPosition() called dir=" + direction
                      + " — STUBBED, no order placed.");
        }
    }
}
