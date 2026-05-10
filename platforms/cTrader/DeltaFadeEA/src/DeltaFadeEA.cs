// ===================================================================
//  DeltaFadeEA — cTrader / cAlgo port
//  Contrarian / trend-pullback scalper that fades cumulative tick &
//  volume delta extremes using dynamic Median+MAD thresholds over a
//  rolling analysis window. Optional EMA trend filter, VWP-slope
//  confirmation, daily trade cap, bar cooldown, trailing stop.
//
//  Parity reference: platforms/MT5/DeltaFadeEA/src/*.mq5 / *.mqh
//
//  Visual layer (rectangles, footprint line, threshold HUD, delta
//  labels) is INTENTIONALLY OMITTED — see README.md "Known gaps".
//  Signal logic is faithful to the MT5 EA at v3.00.
// ===================================================================
using System;
using System.Collections.Generic;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None, AddIndicators = true, TimeZone = TimeZones.UTC)]
    public class DeltaFadeEA : Robot
    {
        // ============================================================
        //  Config (inputs)
        // ============================================================
        [Parameter("Enable Trading", DefaultValue = true)]
        public bool EnableTrading { get; set; }

        [Parameter("Order Label", DefaultValue = "DeltaFadeEA")]
        public string TradeLabel { get; set; }

        // -- Sliding window --
        [Parameter("Window Size (bars)", DefaultValue = 20, MinValue = 2)]
        public int WindowSize { get; set; }

        [Parameter("Analysis Window Size (bars)", DefaultValue = 50, MinValue = 10)]
        public int AnalysisWindowSize { get; set; }

        // -- Trend filter --
        [Parameter("Trend EMA Period (0=off)", DefaultValue = 50, MinValue = 0)]
        public int TrendEMAPeriod { get; set; }

        [Parameter("Trend Following (else Contrarian)", DefaultValue = true)]
        public bool TrendFollowing { get; set; }

        // -- Signal tuning --
        [Parameter("Threshold Multiplier (MAD)", DefaultValue = 2.0, MinValue = 0.1, Step = 0.1)]
        public double ThresholdMultiplier { get; set; }

        [Parameter("Require BOTH deltas", DefaultValue = true)]
        public bool RequireBothDeltas { get; set; }

        [Parameter("Require VWP Slope Confirmation", DefaultValue = true)]
        public bool RequireSlopeConfirmation { get; set; }

        // -- Trade management --
        [Parameter("Max Trades / Day (0=unlimited)", DefaultValue = 5, MinValue = 0)]
        public int MaxTradesPerDay { get; set; }

        [Parameter("Min Bars Between Trades", DefaultValue = 10, MinValue = 0)]
        public int MinBarsBetweenTrades { get; set; }

        // -- Risk --
        [Parameter("Lot Size (0=risk-based)", DefaultValue = 0.01, MinValue = 0.0)]
        public double LotSize { get; set; }

        [Parameter("Risk % per Trade", DefaultValue = 2.0, MinValue = 0.1, Step = 0.1)]
        public double RiskPercent { get; set; }

        [Parameter("Stop Loss (Points)", DefaultValue = 500, MinValue = 1)]
        public int StopLossPoints { get; set; }

        [Parameter("Take Profit (Points, 0=use RR)", DefaultValue = 0, MinValue = 0)]
        public int TakeProfitPoints { get; set; }

        [Parameter("Risk:Reward Ratio (TP)", DefaultValue = 0.6, MinValue = 0.1, Step = 0.1)]
        public double RiskRewardRatio { get; set; }

        [Parameter("Max Spread (Points)", DefaultValue = 30, MinValue = 1)]
        public int MaxSpread { get; set; }

        [Parameter("Trailing Start (Points)", DefaultValue = 200, MinValue = 0)]
        public int TrailingStart { get; set; }

        // -- Session --
        [Parameter("Enable Time Filter", DefaultValue = true)]
        public bool EnableTimeFilter { get; set; }

        [Parameter("Session Start Hour", DefaultValue = 8, MinValue = 0, MaxValue = 23)]
        public int StartHour { get; set; }

        [Parameter("Session End Hour", DefaultValue = 17, MinValue = 0, MaxValue = 23)]
        public int EndHour { get; set; }

        // ============================================================
        //  Constants
        // ============================================================
        private const string Prefix = "[DeltaFadeEA-cT] ";
        private const double VwpCloseWeight   = 0.4;
        private const double VwpTypicalWeight = 0.4;
        private const double VwpOpenWeight    = 0.2;
        private const double ThresholdMinMult     = 0.3;
        private const double ThresholdMaxMult     = 3.0;
        private const double MinAbsoluteThreshold = 80.0;
        private const double MinMadValue          = 10.0;
        private const double MadScaleFactor       = 1.4826;

        // Base thresholds — used as bounds for clamping
        private const double BaseTickBuyThreshold     =  1000;
        private const double BaseTickSellThreshold    = -1000;
        private const double BaseVolumeBuyThreshold   =  800;
        private const double BaseVolumeSellThreshold  = -800;

        // ============================================================
        //  State
        // ============================================================
        private double[] _volumeDelta;
        private double[] _tickDelta;
        private double[] _typicalPrices;
        private double[] _vwp;

        private double _cumVolumeDelta;
        private double _cumTickDelta;

        // FIFO sliding analysis windows (newest at index 0)
        private List<double> _tickAnalysis;
        private List<double> _volumeAnalysis;

        // Dynamic thresholds
        private double _dynTickBuy   =  1000;
        private double _dynTickSell  = -1000;
        private double _dynVolBuy    =  800;
        private double _dynVolSell   = -800;

        // Signal flags (set in CheckTradingSignals, read in OnBar)
        private bool _signalLong;
        private bool _signalShort;

        // Trade management state
        private int _tradesToday;
        private DateTime _lastTradeDay = DateTime.MinValue;
        private int _barsSinceLastTrade = 999;

        // EMA
        private ExponentialMovingAverage _ema;

        // ============================================================
        //  Lifecycle
        // ============================================================
        protected override void OnStart()
        {
            _volumeDelta   = new double[WindowSize];
            _tickDelta     = new double[WindowSize];
            _typicalPrices = new double[WindowSize];
            _vwp           = new double[WindowSize];

            _tickAnalysis   = new List<double>(AnalysisWindowSize);
            _volumeAnalysis = new List<double>(AnalysisWindowSize);

            if (TrendEMAPeriod > 0)
                _ema = Indicators.ExponentialMovingAverage(Bars.ClosePrices, TrendEMAPeriod);

            CalculateDeltas();
            CalculateVolumeFootprint();
            SeedAnalysisWindows();
            RecalcDynamicThresholds();

            Print(Prefix + "v1.00 initialised. Mode=" + (TrendFollowing ? "TrendPullback" : "Contrarian")
                  + "  EMA=" + TrendEMAPeriod
                  + "  BothDeltas=" + RequireBothDeltas
                  + "  SlopeConfirm=" + RequireSlopeConfirmation
                  + "  MaxTrades/Day=" + MaxTradesPerDay
                  + "  Cooldown=" + MinBarsBetweenTrades + " bars");
        }

        protected override void OnStop()
        {
            Print(Prefix + "stopped");
        }

        protected override void OnBar()
        {
            _barsSinceLastTrade++;

            CalculateDeltas();
            CalculateVolumeFootprint();

            if (WindowSize > 1)
            {
                PushFifo(_tickAnalysis,   _tickDelta[1],   AnalysisWindowSize);
                PushFifo(_volumeAnalysis, _volumeDelta[1], AnalysisWindowSize);
                RecalcDynamicThresholds();
            }

            if (EnableTrading && IsTradingAllowed())
                EvaluateAndExecute();
        }

        // OnTick is reserved for trailing-stop management, so SL gets
        // refreshed intra-bar like the MT5 sibling.
        protected override void OnTick()
        {
            if (EnableTrading)
                ManagePositions();
        }

        // ============================================================
        //  Market layer — delta + footprint
        // ============================================================
        // Mapping: index 0 in the EA buffers == newest bar (live, Last(0)).
        // index WindowSize-1 == oldest bar in the window.
        private static double SignedTickVolume(double open, double close, double tickVolume)
        {
            if (close > open) return  tickVolume;
            if (close < open) return -tickVolume;
            return 0;
        }

        private void CalculateDeltas()
        {
            if (Bars.Count < WindowSize) return;

            _cumVolumeDelta = 0;
            _cumTickDelta   = 0;

            for (int i = 0; i < WindowSize; i++)
            {
                double open  = Bars.OpenPrices.Last(i);
                double close = Bars.ClosePrices.Last(i);
                double high  = Bars.HighPrices.Last(i);
                double low   = Bars.LowPrices.Last(i);
                double tv    = Bars.TickVolumes.Last(i);

                _volumeDelta[i] = SignedTickVolume(open, close, tv);

                double range = high - low;
                _tickDelta[i] = (range > 0) ? tv * ((close - open) / range) : 0.0;

                _cumVolumeDelta += _volumeDelta[i];
                _cumTickDelta   += _tickDelta[i];
            }
        }

        private void CalculateVolumeFootprint()
        {
            if (Bars.Count < WindowSize) return;

            for (int i = 0; i < WindowSize; i++)
            {
                double open  = Bars.OpenPrices.Last(i);
                double close = Bars.ClosePrices.Last(i);
                double high  = Bars.HighPrices.Last(i);
                double low   = Bars.LowPrices.Last(i);
                double tv    = Bars.TickVolumes.Last(i);

                _typicalPrices[i] = (high + low + close) / 3.0;
                _vwp[i] = (tv > 0)
                    ? close * VwpCloseWeight + _typicalPrices[i] * VwpTypicalWeight + open * VwpOpenWeight
                    : _typicalPrices[i];
            }
        }

        // VWP slope: +1 up, -1 down, 0 flat (MT5 parity: oldest=Last index, newest=index 0)
        private int GetVolumeLineSlope()
        {
            if (WindowSize < 2) return 0;
            double oldest = _vwp[WindowSize - 1];
            double newest = _vwp[0];
            if (newest > oldest) return  1;
            if (newest < oldest) return -1;
            return 0;
        }

        private void SeedAnalysisWindows()
        {
            int target = Math.Min(Bars.Count - 1, AnalysisWindowSize);
            // Seed using closed bars 1..target (skip live bar at Last(0))
            for (int i = target; i >= 1; i--)
            {
                double open  = Bars.OpenPrices.Last(i);
                double close = Bars.ClosePrices.Last(i);
                double tv    = Bars.TickVolumes.Last(i);
                double delta = SignedTickVolume(open, close, tv);
                PushFifo(_tickAnalysis,   delta, AnalysisWindowSize);
                PushFifo(_volumeAnalysis, delta, AnalysisWindowSize);
            }
            Print(Prefix + "Analysis windows seeded: " + _tickAnalysis.Count + "/" + AnalysisWindowSize);
        }

        private static void PushFifo(List<double> list, double value, int maxSize)
        {
            list.Insert(0, value);
            if (list.Count > maxSize)
                list.RemoveAt(list.Count - 1);
        }

        private static double Median(IEnumerable<double> data)
        {
            var sorted = data.OrderBy(d => d).ToArray();
            int n = sorted.Length;
            if (n == 0) return 0;
            return (n % 2 == 0) ? (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0 : sorted[n / 2];
        }

        private static double Mad(IEnumerable<double> data, double median)
        {
            var devs = data.Select(d => Math.Abs(d - median));
            return Median(devs) * MadScaleFactor;
        }

        // ============================================================
        //  Signal layer — dynamic thresholds + entry decision
        // ============================================================
        private void RecalcDynamicThresholds()
        {
            CalcThresholds(_tickAnalysis,
                           BaseTickBuyThreshold, BaseTickSellThreshold,
                           out _dynTickBuy, out _dynTickSell);
            CalcThresholds(_volumeAnalysis,
                           BaseVolumeBuyThreshold, BaseVolumeSellThreshold,
                           out _dynVolBuy, out _dynVolSell);
        }

        private void CalcThresholds(List<double> data,
                                    double baseBuy, double baseSell,
                                    out double buyThr, out double sellThr)
        {
            if (data.Count < 10)
            {
                buyThr = baseBuy;
                sellThr = baseSell;
                return;
            }

            double med = Median(data);
            double mad = Math.Max(Mad(data, med), MinMadValue);

            double rawBuy  = med + ThresholdMultiplier * mad;
            double rawSell = med - ThresholdMultiplier * mad;

            if (Math.Abs(rawBuy)  < MinAbsoluteThreshold)
                rawBuy  = (rawBuy  >= 0) ?  MinAbsoluteThreshold : -MinAbsoluteThreshold;
            if (Math.Abs(rawSell) < MinAbsoluteThreshold)
                rawSell = (rawSell >= 0) ?  MinAbsoluteThreshold : -MinAbsoluteThreshold;

            buyThr  = ClampThreshold(rawBuy,  baseBuy,  isBuy: true);
            sellThr = ClampThreshold(rawSell, baseSell, isBuy: false);
        }

        // Sign-aware bounds clamp — buy thresholds stay positive, sell stays negative.
        private static double ClampThreshold(double raw, double baseVal, bool isBuy)
        {
            if (isBuy)
            {
                if (raw < 0) raw = Math.Abs(raw);
                return Math.Min(Math.Max(raw, baseVal * ThresholdMinMult), baseVal * ThresholdMaxMult);
            }
            else
            {
                if (raw > 0) raw = -raw;
                return Math.Max(Math.Min(raw, baseVal * ThresholdMinMult), baseVal * ThresholdMaxMult);
            }
        }

        private bool IsTradeAllowedByLimits()
        {
            if (MaxTradesPerDay > 0 && _tradesToday >= MaxTradesPerDay) return false;
            if (_barsSinceLastTrade < MinBarsBetweenTrades)              return false;
            return true;
        }

        private int GetTrendDirection()
        {
            if (TrendEMAPeriod <= 0 || _ema == null) return 0;
            double bid = Symbol.Bid;
            double emaVal = _ema.Result.LastValue;
            if (bid > emaVal) return  1;
            if (bid < emaVal) return -1;
            return 0;
        }

        private void CheckTradingSignals()
        {
            _signalLong  = false;
            _signalShort = false;

            // Spread filter (Symbol.Spread is in price units, convert MaxSpread points → price)
            if (Symbol.Spread > MaxSpread * Symbol.TickSize) return;

            UpdateDailyTradeCount();
            if (!IsTradeAllowedByLimits()) return;

            bool tickOverbought = _cumTickDelta   > _dynTickBuy;
            bool tickOversold   = _cumTickDelta   < _dynTickSell;
            bool volOverbought  = _cumVolumeDelta > _dynVolBuy;
            bool volOversold    = _cumVolumeDelta < _dynVolSell;

            bool deltaOverbought, deltaOversold;
            if (RequireBothDeltas)
            {
                deltaOverbought = tickOverbought && volOverbought;
                deltaOversold   = tickOversold   && volOversold;
            }
            else
            {
                deltaOverbought = tickOverbought || volOverbought;
                deltaOversold   = tickOversold   || volOversold;
            }

            int slope = GetVolumeLineSlope();
            bool slopeUp   = !RequireSlopeConfirmation || slope ==  1;
            bool slopeDown = !RequireSlopeConfirmation || slope == -1;

            int trend = GetTrendDirection();

            if (TrendFollowing && trend != 0)
            {
                if (trend == 1 && deltaOversold && slopeDown)
                {
                    _signalLong = true;
                    Print(Prefix + "LONG — uptrend pullback (EMA + delta oversold + red slope)");
                }
                else if (trend == -1 && deltaOverbought && slopeUp)
                {
                    _signalShort = true;
                    Print(Prefix + "SHORT — downtrend bounce (EMA + delta overbought + green slope)");
                }
            }
            else
            {
                if (deltaOverbought && slopeUp)
                {
                    _signalShort = true;
                    Print(Prefix + "SHORT — contrarian fade (delta overbought)");
                }
                else if (deltaOversold && slopeDown)
                {
                    _signalLong = true;
                    Print(Prefix + "LONG — contrarian fade (delta oversold)");
                }
            }
        }

        private void UpdateDailyTradeCount()
        {
            DateTime today = Server.Time.Date;
            if (today != _lastTradeDay)
            {
                _tradesToday  = 0;
                _lastTradeDay = today;
            }
        }

        private void OnTradeExecuted()
        {
            _tradesToday++;
            _barsSinceLastTrade = 0;
        }

        // ============================================================
        //  Risk layer — lot sizing and SL/TP prices
        // ============================================================
        private double CalculatePositionUnits()
        {
            if (LotSize > 0)
                return Symbol.NormalizeVolumeInUnits(Symbol.QuantityToVolumeInUnits(LotSize));

            // Risk-based: loss = StopLossPoints * Symbol.TickValue * volumeInUnits
            // → volumeInUnits = (balance * risk%) / (StopLossPoints * Symbol.TickValue)
            double riskAmt = Account.Balance * RiskPercent / 100.0;
            if (Symbol.TickValue <= 0 || StopLossPoints <= 0)
                return Symbol.NormalizeVolumeInUnits(Symbol.VolumeInUnitsMin);

            double units = riskAmt / (StopLossPoints * Symbol.TickValue);
            return Symbol.NormalizeVolumeInUnits(units);
        }

        private int GetTpPoints()
        {
            return (TakeProfitPoints > 0)
                ? TakeProfitPoints
                : (int)Math.Round(StopLossPoints * RiskRewardRatio);
        }

        private double PointsToPips(int points)
        {
            return (points * Symbol.TickSize) / Symbol.PipSize;
        }

        // ============================================================
        //  Trade layer — entries + position management
        // ============================================================
        private bool HasPosition(TradeType direction)
        {
            return Positions.Any(p =>
                p.SymbolName == Symbol.Name &&
                p.Label == TradeLabel &&
                p.TradeType == direction);
        }

        private void EnterLong()
        {
            double slPips = PointsToPips(StopLossPoints);
            double tpPips = PointsToPips(GetTpPoints());
            double units  = CalculatePositionUnits();

            var res = ExecuteMarketOrder(TradeType.Buy, Symbol.Name, units, TradeLabel, slPips, tpPips);
            if (res.IsSuccessful)
            {
                Print(Prefix + "BUY opened — id=" + res.Position.Id);
                OnTradeExecuted();
            }
            else
            {
                Print(Prefix + "BUY failed err=" + res.Error);
            }
        }

        private void EnterShort()
        {
            double slPips = PointsToPips(StopLossPoints);
            double tpPips = PointsToPips(GetTpPoints());
            double units  = CalculatePositionUnits();

            var res = ExecuteMarketOrder(TradeType.Sell, Symbol.Name, units, TradeLabel, slPips, tpPips);
            if (res.IsSuccessful)
            {
                Print(Prefix + "SELL opened — id=" + res.Position.Id);
                OnTradeExecuted();
            }
            else
            {
                Print(Prefix + "SELL failed err=" + res.Error);
            }
        }

        private void ManagePositions()
        {
            var ours = Positions.Where(p => p.SymbolName == Symbol.Name && p.Label == TradeLabel).ToList();
            foreach (var pos in ours)
                ApplyTrailingStop(pos);
        }

        private void ApplyTrailingStop(Position pos)
        {
            double trail = TrailingStart * Symbol.TickSize;
            if (trail <= 0) return;

            double openPx = pos.EntryPrice;
            double curSL  = pos.StopLoss ?? 0.0;
            double curTP  = pos.TakeProfit ?? 0.0;

            if (pos.TradeType == TradeType.Buy)
            {
                double newSL = Symbol.Bid - trail;
                if (newSL > curSL && newSL > openPx)
                    SafeModify(pos, newSL, curTP);
            }
            else
            {
                double newSL = Symbol.Ask + trail;
                bool slUnset = pos.StopLoss == null;
                if ((slUnset || newSL < curSL) && newSL < openPx)
                    SafeModify(pos, newSL, curTP);
            }
        }

        private void SafeModify(Position pos, double newSL, double tp)
        {
            double? tpArg = (tp > 0) ? (double?)tp : null;
            var res = ModifyPosition(pos, newSL, tpArg);
            if (!res.IsSuccessful)
                Print(Prefix + "Trailing modify failed id=" + pos.Id + " err=" + res.Error);
        }

        // ============================================================
        //  Utils — session filter + dispatch helper
        // ============================================================
        private bool IsTradingAllowed()
        {
            if (!EnableTimeFilter) return true;
            DateTime t = Server.Time;
            if (t.DayOfWeek == DayOfWeek.Saturday || t.DayOfWeek == DayOfWeek.Sunday) return false;
            int h = t.Hour;
            return (StartHour <= EndHour)
                ? (h >= StartHour && h <  EndHour)
                : (h >= StartHour || h <  EndHour);
        }

        private void EvaluateAndExecute()
        {
            CheckTradingSignals();

            if (_signalLong  && !HasPosition(TradeType.Buy))  EnterLong();
            if (_signalShort && !HasPosition(TradeType.Sell)) EnterShort();
        }
    }
}
