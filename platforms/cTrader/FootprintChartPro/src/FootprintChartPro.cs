// ===================================================================
//  FootprintChartPro — cTrader / cAlgo SCAFFOLD (WIP)
//
//  cAlgo Indicator that draws a minimal viable delta-cell footprint
//  on the active chart. The MT5 sibling has 11 analysis panels, 16
//  themes, volume inference engine, and 3-tier imbalance detection —
//  none of those are ported here. See README "Known Gaps".
//
//  WHAT THIS DOES:
//    - Per-tick: bucket bid into N-pip price levels for the live bar
//    - Per-bar: render delta cells (price × bid/ask vol) above each bar
//
//  Parity reference: platforms/MT5/FootprintChartPro/src/*.mqh
// ===================================================================
using System;
using System.Collections.Generic;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Indicators
{
    [Indicator(IsOverlay = true, AccessRights = AccessRights.None, AutoRescale = false)]
    public class FootprintChartPro : Indicator
    {
        [Parameter("Block Size (pips)", DefaultValue = 1.0, MinValue = 0.1, Step = 0.1)]
        public double BlockPips { get; set; }

        [Parameter("Max Bars Back", DefaultValue = 30, MinValue = 1)]
        public int MaxBarsBack { get; set; }

        [Parameter("Cell Width (chart sec)", DefaultValue = 30, MinValue = 1)]
        public int CellWidthSeconds { get; set; }

        [Parameter("Show Live Bar", DefaultValue = true)]
        public bool ShowLiveBar { get; set; }

        [Parameter("Color: Buy", DefaultValue = "FF1E90FF")]
        public string BuyColorHex { get; set; }

        [Parameter("Color: Sell", DefaultValue = "FFDC143C")]
        public string SellColorHex { get; set; }

        [Parameter("Color: POC (highest vol)", DefaultValue = "FF800080")]
        public string POCColorHex { get; set; }

        private const string Prefix = "[FootprintChartPro-cT-WIP] ";
        private const string ObjPrefix = "FCP_";

        // Per-bar buckets keyed by bar open time
        private Dictionary<DateTime, Dictionary<int, BucketStats>> _barBuckets;
        private DateTime _lastSeenBarTime;
        private double _lastBid;

        private struct BucketStats
        {
            public int BuyCount;
            public int SellCount;
        }

        protected override void Initialize()
        {
            _barBuckets = new Dictionary<DateTime, Dictionary<int, BucketStats>>();
            _lastSeenBarTime = Bars.OpenTimes.LastValue;
            _lastBid = Symbol.Bid;
            Print(Prefix + "SCAFFOLD initialised — minimal viable footprint only. Panel suite NOT ported.");
        }

        public override void Calculate(int index)
        {
            // Indicator's Calculate fires per-bar tick; use it as a per-tick hook.
            DateTime barTime = Bars.OpenTimes[index];
            double bid = Symbol.Bid;

            if (!_barBuckets.TryGetValue(barTime, out var buckets))
            {
                buckets = new Dictionary<int, BucketStats>();
                _barBuckets[barTime] = buckets;
                if (_barBuckets.Count > MaxBarsBack)
                {
                    var oldest = _barBuckets.Keys.OrderBy(t => t).First();
                    _barBuckets.Remove(oldest);
                    RemoveBarObjects(oldest);
                }
            }

            int bucketIdx = PriceToBucket(bid);
            BucketStats stats;
            buckets.TryGetValue(bucketIdx, out stats);

            // Classify uptick = buy, downtick = sell (no real trade-side data in cAlgo)
            if (bid > _lastBid) stats.BuyCount++;
            else if (bid < _lastBid) stats.SellCount++;
            buckets[bucketIdx] = stats;
            _lastBid = bid;

            // Re-render this bar's cells when bid changes (cheap; only the live bar updates)
            if (barTime != _lastSeenBarTime || index == Bars.Count - 1)
            {
                RenderBar(barTime, buckets);
                _lastSeenBarTime = barTime;
            }
        }

        private int PriceToBucket(double price)
        {
            double blockSize = BlockPips * Symbol.PipSize;
            return (int)Math.Floor(price / blockSize);
        }

        private void RenderBar(DateTime barTime, Dictionary<int, BucketStats> buckets)
        {
            if (!ShowLiveBar && barTime == Bars.OpenTimes.LastValue) return;

            // Find POC (bucket with highest total volume)
            int pocIdx = -1;
            int pocVol = 0;
            foreach (var kv in buckets)
            {
                int total = kv.Value.BuyCount + kv.Value.SellCount;
                if (total > pocVol) { pocVol = total; pocIdx = kv.Key; }
            }

            double blockSize = BlockPips * Symbol.PipSize;
            DateTime cellEnd = barTime.AddSeconds(CellWidthSeconds);

            foreach (var kv in buckets)
            {
                int idx = kv.Key;
                var stats = kv.Value;
                int delta = stats.BuyCount - stats.SellCount;
                int total = stats.BuyCount + stats.SellCount;
                if (total == 0) continue;

                double cellLow  = idx * blockSize;
                double cellHigh = cellLow + blockSize;
                bool isPOC = (idx == pocIdx);

                Color clr = isPOC
                    ? Color.FromHex(POCColorHex)
                    : (delta > 0 ? Color.FromHex(BuyColorHex)
                                 : (delta < 0 ? Color.FromHex(SellColorHex) : Color.Gray));

                string rectName = ObjPrefix + "RECT_" + barTime.Ticks + "_" + idx;
                Chart.DrawRectangle(rectName, barTime, cellLow, cellEnd, cellHigh, clr, 1, LineStyle.Solid);

                string txtName = ObjPrefix + "TX_" + barTime.Ticks + "_" + idx;
                string text = (delta > 0 ? "+" : "") + delta;
                var t = Chart.DrawText(txtName, text, barTime.AddSeconds(CellWidthSeconds / 2),
                                       (cellLow + cellHigh) / 2, Color.White);
                t.HorizontalAlignment = HorizontalAlignment.Center;
                t.VerticalAlignment   = VerticalAlignment.Center;
                t.FontSize = 7;
            }
        }

        private void RemoveBarObjects(DateTime barTime)
        {
            string keyPart = barTime.Ticks.ToString();
            var toRemove = Chart.Objects
                .Where(o => o.Name != null && o.Name.StartsWith(ObjPrefix) && o.Name.Contains(keyPart))
                .Select(o => o.Name)
                .ToList();
            foreach (var name in toRemove) Chart.RemoveObject(name);
        }
    }
}
