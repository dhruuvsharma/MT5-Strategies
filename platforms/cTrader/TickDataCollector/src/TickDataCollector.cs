// ===================================================================
//  TickDataCollector — cTrader / cAlgo port
//  Writes every tick as a CSV row with running candle-window OHLC,
//  delta context, spread, and cumulative delta. For Python backtest.
//
//  CSV schema (matches MT5 sibling):
//    DateTime, Ms, Price, Bid, Ask, SpreadPts, Volume, Direction,
//    CandleOpen, CandleHigh, CandleLow, CandleDelta, CandleVolDelta,
//    TicksPerSec, CumDelta, Session
//
//  Parity reference: platforms/MT5/TickDataCollector/src/TickDataCollector.mq5
//
//  cTrader caveat: per-tick "Volume" is recorded as 1 unit (matches MT5
//  Forex). Spread is converted from Symbol.Spread (price units) to
//  points via Symbol.TickSize.
// ===================================================================
using System;
using System.IO;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.FileSystem, AddIndicators = false, TimeZone = TimeZones.UTC)]
    public class TickDataCollector : Robot
    {
        [Parameter("Output Filename (blank = auto)", DefaultValue = "")]
        public string CSVFileName { get; set; }

        [Parameter("Output Folder (blank = MyDocuments\\cAlgoData)", DefaultValue = "")]
        public string OutputFolder { get; set; }

        [Parameter("Append Mode", DefaultValue = false)]
        public bool AppendMode { get; set; }

        [Parameter("Candle Window Minutes", DefaultValue = 1, MinValue = 1)]
        public int CandleMinutes { get; set; }

        [Parameter("Session Filter (ALL|Asian|London|London-NewYork|NewYork)", DefaultValue = "ALL")]
        public string SessionFilter { get; set; }

        [Parameter("Price-Change Only", DefaultValue = false)]
        public bool PriceChangeOnly { get; set; }

        [Parameter("Flush Every N Ticks", DefaultValue = 500, MinValue = 1)]
        public int FlushEveryN { get; set; }

        private const string Prefix = "[TickCollector-cT] ";

        private StreamWriter _writer;
        private string _filePath;

        private DateTime _candleTime  = DateTime.MinValue;
        private DateTime _candleStart = DateTime.MinValue;
        private double _cOpen, _cHigh, _cLow;
        private int    _upTicks, _downTicks;
        private double _upVol, _downVol;
        private double _lastPrice;
        private long   _tickCount;
        private int    _cumDelta;

        protected override void OnStart()
        {
            string folder = string.IsNullOrEmpty(OutputFolder)
                ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "cAlgoData")
                : OutputFolder;
            Directory.CreateDirectory(folder);

            string filename = string.IsNullOrEmpty(CSVFileName) ? BuildFilename() : CSVFileName;
            _filePath = Path.Combine(folder, filename);

            bool fileExists = File.Exists(_filePath);
            var stream = new FileStream(_filePath,
                AppendMode ? FileMode.Append : FileMode.Create,
                FileAccess.Write, FileShare.Read);
            _writer = new StreamWriter(stream);
            if (!AppendMode || !fileExists)
                WriteHeader();

            Print(Prefix + "Started | File: " + _filePath + " | CandleWindow: " + CandleMinutes + "min");
        }

        protected override void OnStop()
        {
            if (_writer == null) return;
            _writer.Flush();
            _writer.Dispose();
            Print(Prefix + "Stopped | Ticks written: " + _tickCount);
        }

        protected override void OnTick()
        {
            double bid = Symbol.Bid;
            double ask = Symbol.Ask;
            double price = (bid > 0 && ask > 0) ? (bid + ask) * 0.5 : bid;
            DateTime tickTime = Server.Time;
            DateTime newCandleTime = TruncateToCandle(tickTime);

            if (newCandleTime != _candleTime)
            {
                _candleTime  = newCandleTime;
                _candleStart = tickTime;
                _cOpen = _cHigh = _cLow = price;
                _upTicks = _downTicks = 0;
                _upVol = _downVol = 0;
                _lastPrice = 0;
            }

            if (PriceChangeOnly && price == _lastPrice && _lastPrice > 0) return;

            const double tickVol = 1.0;
            string dir = "NEUTRAL";
            if (_lastPrice > 0)
            {
                if (price > _lastPrice)      { _upTicks++;   _upVol   += tickVol; dir = "UP";   _cumDelta++; }
                else if (price < _lastPrice) { _downTicks++; _downVol += tickVol; dir = "DOWN"; _cumDelta--; }
            }

            if (price > _cHigh) _cHigh = price;
            if (price < _cLow || _cLow == 0) _cLow = price;

            _lastPrice = price;

            string session = GetSession(tickTime);
            if (SessionFilter != "ALL" && SessionFilter != session) return;

            int    cDelta  = _upTicks - _downTicks;
            double cvDelta = _upVol - _downVol;
            int    elapsed = (int)Math.Round((tickTime - _candleStart).TotalSeconds);
            double tps     = (elapsed > 0) ? (double)(_upTicks + _downTicks) / elapsed : 0.0;
            double spreadPts = Math.Round(Symbol.Spread / Symbol.TickSize, 1);
            int    ms      = tickTime.Millisecond;

            int digits = Symbol.Digits;
            var inv = System.Globalization.CultureInfo.InvariantCulture;
            string row = string.Format(inv,
                "{0:yyyy.MM.dd HH:mm:ss},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12:F2},{13:F2},{14},{15}",
                tickTime, ms,
                price.ToString("F" + digits, inv),
                bid  .ToString("F" + digits, inv),
                ask  .ToString("F" + digits, inv),
                spreadPts.ToString("F1", inv),
                (long)tickVol,
                dir,
                _cOpen.ToString("F" + digits, inv),
                _cHigh.ToString("F" + digits, inv),
                _cLow .ToString("F" + digits, inv),
                cDelta, cvDelta, tps, _cumDelta, session);

            _writer.WriteLine(row);
            _tickCount++;
            if (_tickCount % FlushEveryN == 0) _writer.Flush();
        }

        private DateTime TruncateToCandle(DateTime t)
        {
            int periodSec = CandleMinutes * 60;
            long ticksPerPeriod = TimeSpan.TicksPerSecond * periodSec;
            return new DateTime((t.Ticks / ticksPerPeriod) * ticksPerPeriod, t.Kind);
        }

        private void WriteHeader()
        {
            _writer.WriteLine("DateTime,Ms,Price,Bid,Ask,SpreadPts,Volume,Direction,CandleOpen,CandleHigh,CandleLow,CandleDelta,CandleVolDelta,TicksPerSec,CumDelta,Session");
        }

        private string BuildFilename()
        {
            DateTime now = Server.Time;
            return string.Format("{0}_ticks_{1:yyyyMMdd}.csv", Symbol.Name, now);
        }

        private static string GetSession(DateTime t)
        {
            int h = t.Hour;
            if (h >= 23 || h < 8) return "Asian";
            if (h < 13) return "London";
            if (h < 16) return "London-NewYork";
            if (h < 22) return "NewYork";
            return "OffHours";
        }
    }
}
