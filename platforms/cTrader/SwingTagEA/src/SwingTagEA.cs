// ===================================================================
//  SwingTagEA — cTrader / cAlgo port
//  3-bar swing pivot fade: SELL LIMIT at mid-bar high when both
//  extremes peak above the oldest bar; BUY LIMIT at mid-bar low when
//  both extremes trough below. DAX-focused, 13:00-16:00 session.
//
//  Parity reference: platforms/MT5/SwingTagEA/src/SwingTagEA.mq5
// ===================================================================
using System;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None, AddIndicators = false, TimeZone = TimeZones.UTC)]
    public class SwingTagEA : Robot
    {
        // -------- Config (inputs) --------
        [Parameter("Volume (Lots)", DefaultValue = 0.1, MinValue = 0.01, Step = 0.01)]
        public double Lots { get; set; }

        [Parameter("Stop Loss (Points)", DefaultValue = 2000, MinValue = 1)]
        public int SLPoints { get; set; }

        [Parameter("Take Profit (Points)", DefaultValue = 2000, MinValue = 1)]
        public int TPPoints { get; set; }

        [Parameter("Smart Order Management", DefaultValue = true)]
        public bool OrderManagement { get; set; }

        [Parameter("Use Trading Hours", DefaultValue = true)]
        public bool UseTradingHours { get; set; }

        [Parameter("Session Start (HH:MM)", DefaultValue = "13:00")]
        public string TradingStartTime { get; set; }

        [Parameter("Session End (HH:MM)", DefaultValue = "16:00")]
        public string TradingEndTime { get; set; }

        [Parameter("Order Label", DefaultValue = "SwingTagEA")]
        public string TradeLabel { get; set; }

        // -------- Constants --------
        private const int MinBarsRequired = 4;
        private const string HighLinePrefix = "HighLine";
        private const string LowLinePrefix = "LowLine";
        private const int LineWidth = 2;
        private const string Prefix = "[SwingTagEA-cT] ";

        private DateTime _lastProcessedBarTime = DateTime.MinValue;

        // -------- Lifecycle --------
        protected override void OnStart()
        {
            Print(Prefix + "Initialised on " + Symbol.Name + " " + TimeFrame);
        }

        protected override void OnStop()
        {
            DeleteChartObjects(HighLinePrefix);
            DeleteChartObjects(LowLinePrefix);
            Print(Prefix + "Stopped");
        }

        // OnBar fires when a new bar opens — i.e. the previous bar just closed.
        // Last(1) == just-closed bar (== MT5's bar[1]); Last(2)/Last(3) == older bars.
        protected override void OnBar()
        {
            if (UseTradingHours && !IsWithinTradingHours()) return;
            if (Bars.Count < MinBarsRequired) return;

            DateTime currentBarTime = Bars.OpenTimes.LastValue;
            if (currentBarTime == _lastProcessedBarTime) return;
            _lastProcessedBarTime = currentBarTime;

            CandleData data = GetCandleData();

            bool highGreen = IsMidHighAboveOld(data);
            bool lowGreen  = IsMidLowAboveOld(data);

            UpdateDrawings(data, highGreen, lowGreen, currentBarTime);

            TradeType signalType;
            double entryPrice;
            if (GetSignal(data, out signalType, out entryPrice))
                ProcessSignal(signalType, entryPrice);
        }

        // ====================================================================
        //  Market layer — bar data retrieval
        // ====================================================================
        private struct CandleData
        {
            public double HighOld, HighMid, HighNew;
            public double LowOld,  LowMid,  LowNew;
            public DateTime TimeOld, TimeMid, TimeNew;
        }

        private CandleData GetCandleData()
        {
            CandleData d;
            d.HighOld = Bars.HighPrices.Last(3);
            d.HighMid = Bars.HighPrices.Last(2);
            d.HighNew = Bars.HighPrices.Last(1);

            d.LowOld = Bars.LowPrices.Last(3);
            d.LowMid = Bars.LowPrices.Last(2);
            d.LowNew = Bars.LowPrices.Last(1);

            d.TimeOld = Bars.OpenTimes.Last(3);
            d.TimeMid = Bars.OpenTimes.Last(2);
            d.TimeNew = Bars.OpenTimes.Last(1);
            return d;
        }

        // ====================================================================
        //  Signal layer — pure pivot detection
        //  NOTE: preserves MT5 quirk — original IsAboveLine() reduced to
        //  midVal > oldVal regardless of timestamps. See MT5 Signal.mqh.
        // ====================================================================
        private static bool IsMidHighAboveOld(CandleData d) { return d.HighMid > d.HighOld; }
        private static bool IsMidLowAboveOld(CandleData d)  { return d.LowMid  > d.LowOld;  }

        private static bool DetectBearishPivot(CandleData d)
        {
            return IsMidHighAboveOld(d) && IsMidLowAboveOld(d);
        }

        private static bool DetectBullishPivot(CandleData d)
        {
            return !IsMidHighAboveOld(d) && !IsMidLowAboveOld(d);
        }

        private static bool GetSignal(CandleData d, out TradeType signalType, out double entryPrice)
        {
            if (DetectBearishPivot(d))
            {
                signalType = TradeType.Sell;
                entryPrice = d.HighMid;
                return true;
            }
            if (DetectBullishPivot(d))
            {
                signalType = TradeType.Buy;
                entryPrice = d.LowMid;
                return true;
            }
            signalType = TradeType.Buy;
            entryPrice = 0.0;
            return false;
        }

        // ====================================================================
        //  Risk layer — SL/TP in pips, converted from MT5 "points"
        //  In cAlgo, PlaceLimitOrder takes SL/TP in pips (double).
        //  Conversion: pips = (points * Symbol.TickSize) / Symbol.PipSize
        // ====================================================================
        private double PointsToPips(int points)
        {
            return (points * Symbol.TickSize) / Symbol.PipSize;
        }

        // ====================================================================
        //  Trade layer
        // ====================================================================
        private bool HasActivePosition(TradeType direction)
        {
            return Positions.Any(p =>
                p.SymbolName == Symbol.Name &&
                p.Label == TradeLabel &&
                p.TradeType == direction);
        }

        private void DeletePendingOrdersByType(TradeType direction)
        {
            // PendingOrders.Where returns lazy enumerable; ToList for safe mutation.
            var stale = PendingOrders
                .Where(o => o.SymbolName == Symbol.Name
                         && o.Label == TradeLabel
                         && o.TradeType == direction
                         && o.OrderType == PendingOrderType.Limit)
                .ToList();

            foreach (var order in stale)
            {
                var res = CancelPendingOrder(order);
                if (!res.IsSuccessful)
                    Print(Prefix + "CancelPendingOrder failed err=" + res.Error);
            }
        }

        private bool SendPendingLimitOrder(TradeType direction, double price, double slPips, double tpPips)
        {
            double volume = Symbol.NormalizeVolumeInUnits(Symbol.QuantityToVolumeInUnits(Lots));
            var res = PlaceLimitOrder(direction, Symbol.Name, volume, price, TradeLabel, slPips, tpPips);
            if (!res.IsSuccessful)
                Print(Prefix + "PlaceLimitOrder failed type=" + direction + " price=" + price + " err=" + res.Error);
            return res.IsSuccessful;
        }

        private void ProcessSignal(TradeType direction, double entryPrice)
        {
            if (OrderManagement)
            {
                if (HasActivePosition(direction))
                {
                    Print(Prefix + "Active position exists — skipping signal");
                    return;
                }
                DeletePendingOrdersByType(direction);
            }

            double slPips = PointsToPips(SLPoints);
            double tpPips = PointsToPips(TPPoints);
            SendPendingLimitOrder(direction, entryPrice, slPips, tpPips);
        }

        // ====================================================================
        //  Utils — trading hours + chart drawing
        // ====================================================================
        private bool IsWithinTradingHours()
        {
            int startSec, endSec;
            if (!TryParseHHMM(TradingStartTime, out startSec)) return false;
            if (!TryParseHHMM(TradingEndTime,   out endSec))   return false;

            DateTime now = Server.Time;
            int nowSec = now.Hour * 3600 + now.Minute * 60 + now.Second;
            return (nowSec >= startSec) && (nowSec <= endSec);
        }

        private static bool TryParseHHMM(string s, out int seconds)
        {
            seconds = 0;
            if (string.IsNullOrEmpty(s)) return false;
            var parts = s.Split(':');
            if (parts.Length != 2) return false;
            int h, m;
            if (!int.TryParse(parts[0], out h)) return false;
            if (!int.TryParse(parts[1], out m)) return false;
            seconds = h * 3600 + m * 60;
            return true;
        }

        private void DeleteChartObjects(string prefix)
        {
            var stale = Chart.Objects.Where(o => o.Name != null && o.Name.StartsWith(prefix)).ToList();
            foreach (var obj in stale)
                Chart.RemoveObject(obj.Name);
        }

        private void CreateTrendLine(string name, DateTime t1, double p1, DateTime t2, double p2, Color clr)
        {
            var line = Chart.DrawTrendLine(name, t1, p1, t2, p2, clr, LineWidth);
            line.IsInteractive = false;
        }

        private void DrawTriangle(string prefix,
                                  DateTime t1, double p1,
                                  DateTime t2, double p2,
                                  DateTime t3, double p3,
                                  Color clr)
        {
            CreateTrendLine(prefix + "_1", t1, p1, t2, p2, clr);
            CreateTrendLine(prefix + "_2", t2, p2, t3, p3, clr);
            CreateTrendLine(prefix + "_3", t3, p3, t1, p1, clr);
        }

        private void UpdateDrawings(CandleData d, bool highGreen, bool lowGreen, DateTime currentBarTime)
        {
            DeleteChartObjects(HighLinePrefix);
            DeleteChartObjects(LowLinePrefix);

            string stamp = currentBarTime.ToString("yyyyMMddHHmm");
            string highName = HighLinePrefix + "_" + stamp;
            string lowName  = LowLinePrefix  + "_" + stamp;

            Color highColor = highGreen ? Color.LimeGreen : Color.IndianRed;
            Color lowColor  = lowGreen  ? Color.LimeGreen : Color.IndianRed;

            DrawTriangle(highName,
                         d.TimeOld, d.HighOld,
                         d.TimeMid, d.HighMid,
                         d.TimeNew, d.HighNew,
                         highColor);

            DrawTriangle(lowName,
                         d.TimeOld, d.LowOld,
                         d.TimeMid, d.LowMid,
                         d.TimeNew, d.LowNew,
                         lowColor);
        }
    }
}
