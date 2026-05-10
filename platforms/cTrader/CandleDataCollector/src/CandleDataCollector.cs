// ===================================================================
//  CandleDataCollector — cTrader / cAlgo port
//  Builds tick-aggregated candles and writes one CSV row per candle.
//
//  CSV schema (matches MT5 sibling):
//    DateTime, Open, High, Low, Close, TickDelta, VolumeDelta, Volume,
//    VWAP, Range, TickCount, TicksPerSec, CumDelta, Session
//
//  Parity reference: platforms/MT5/CandleDataCollector/src/CandleDataCollector.mq5
//
//  cTrader caveat: cAlgo OnTick does not expose a per-tick volume.
//  We treat each tick as 1 unit of volume — matches MT5 Forex behaviour
//  (tick.volume == 1 per tick when broker doesn't supply real volume).
// ===================================================================
using System;
using System.IO;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.FileSystem, AddIndicators = false, TimeZone = TimeZones.UTC)]
    public class CandleDataCollector : Robot
    {
        [Parameter("Output Filename (blank = auto)", DefaultValue = "")]
        public string CSVFileName { get; set; }

        [Parameter("Output Folder (blank = MyDocuments\\cAlgoData)", DefaultValue = "")]
        public string OutputFolder { get; set; }

        [Parameter("Append Mode", DefaultValue = false)]
        public bool AppendMode { get; set; }

        [Parameter("Candle Minutes", DefaultValue = 1, MinValue = 1)]
        public int CandleMinutes { get; set; }

        [Parameter("Session Filter (ALL|Asian|London|London-NewYork|NewYork)", DefaultValue = "ALL")]
        public string SessionFilter { get; set; }

        [Parameter("Write Last Candle on Stop", DefaultValue = true)]
        public bool WriteLastCandle { get; set; }

        [Parameter("Print Each Candle", DefaultValue = false)]
        public bool PrintEachCandle { get; set; }

        [Parameter("Flush Every N Candles", DefaultValue = 10, MinValue = 1)]
        public int FlushEveryN { get; set; }

        private const string Prefix = "[CandleCollector-cT] ";

        private StreamWriter _writer;
        private string _filePath;

        private DateTime _candleTime  = DateTime.MinValue;
        private DateTime _candleStart = DateTime.MinValue;
        private double _open, _high, _low, _close;
        private int    _upTicks, _downTicks;
        private double _upVol, _downVol;
        private double _totalVol;
        private double _vwapNumer;
        private double _lastPrice;
        private long   _tickCount;
        private long   _candleCount;
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

            Print(Prefix + "Started | File: " + _filePath + " | TF: " + CandleMinutes + "min");
        }

        protected override void OnStop()
        {
            if (_writer == null) return;
            if (WriteLastCandle && _candleTime != DateTime.MinValue && _tickCount > 0)
                FlushCandle();
            _writer.Flush();
            _writer.Dispose();
            Print(Prefix + "Stopped | Candles written: " + _candleCount);
        }

        protected override void OnTick()
        {
            double price = Symbol.Bid > 0 && Symbol.Ask > 0 ? (Symbol.Bid + Symbol.Ask) * 0.5 : Symbol.Bid;
            DateTime tickTime = Server.Time;
            DateTime newCandleTime = TruncateToCandle(tickTime);

            if (_candleTime == DateTime.MinValue)
            {
                StartCandle(newCandleTime, tickTime, price);
                return;
            }

            if (newCandleTime != _candleTime)
            {
                FlushCandle();
                StartCandle(newCandleTime, tickTime, price);
                return;
            }

            UpdateCandle(price);
        }

        private DateTime TruncateToCandle(DateTime t)
        {
            int periodSec = CandleMinutes * 60;
            long ticksPerPeriod = TimeSpan.TicksPerSecond * periodSec;
            long bucketed = (t.Ticks / ticksPerPeriod) * ticksPerPeriod;
            return new DateTime(bucketed, t.Kind);
        }

        private void StartCandle(DateTime cTime, DateTime tTime, double price)
        {
            _candleTime  = cTime;
            _candleStart = tTime;
            _open = _high = _low = _close = price;
            _upTicks = _downTicks = 0;
            _upVol = _downVol = 0;
            _totalVol  = 1.0;       // first tick = 1 unit
            _vwapNumer = price * 1.0;
            _tickCount = 1;
            _lastPrice = price;
        }

        private void UpdateCandle(double price)
        {
            if (price > _high) _high = price;
            if (price < _low)  _low  = price;

            const double tickVol = 1.0;
            if (price > _lastPrice)      { _upTicks++;   _upVol   += tickVol; }
            else if (price < _lastPrice) { _downTicks++; _downVol += tickVol; }

            _totalVol  += tickVol;
            _vwapNumer += price * tickVol;
            _tickCount++;
            _close = price;
            _lastPrice = price;
        }

        private void FlushCandle()
        {
            string session = GetSession(_candleTime);
            if (SessionFilter != "ALL" && SessionFilter != session) return;

            int    tDelta = _upTicks - _downTicks;
            double vDelta = _upVol - _downVol;
            double vwap   = (_totalVol > 0) ? _vwapNumer / _totalVol : _close;
            double range  = _high - _low;
            int    elapsed = (int)Math.Round((Server.Time - _candleStart).TotalSeconds);
            double tps    = (elapsed > 0) ? (double)_tickCount / elapsed : 0.0;

            _cumDelta += tDelta;

            int digits = Symbol.Digits;
            string row = string.Format(System.Globalization.CultureInfo.InvariantCulture,
                "{0:yyyy.MM.dd HH:mm},{1},{2},{3},{4},{5},{6:F2},{7:F2},{8},{9},{10},{11:F2},{12},{13}",
                _candleTime,
                _open.ToString("F" + digits, System.Globalization.CultureInfo.InvariantCulture),
                _high.ToString("F" + digits, System.Globalization.CultureInfo.InvariantCulture),
                _low .ToString("F" + digits, System.Globalization.CultureInfo.InvariantCulture),
                _close.ToString("F" + digits, System.Globalization.CultureInfo.InvariantCulture),
                tDelta, vDelta, _totalVol,
                vwap.ToString("F" + digits, System.Globalization.CultureInfo.InvariantCulture),
                range.ToString("F" + digits, System.Globalization.CultureInfo.InvariantCulture),
                _tickCount, tps,
                _cumDelta, session);

            _writer.WriteLine(row);
            _candleCount++;

            if (_candleCount % FlushEveryN == 0) _writer.Flush();

            if (PrintEachCandle)
                Print(Prefix + _candleTime + " O:" + _open + " H:" + _high + " L:" + _low + " C:" + _close
                      + " Delta:" + tDelta + " VDelta:" + vDelta);
        }

        private void WriteHeader()
        {
            _writer.WriteLine("DateTime,Open,High,Low,Close,TickDelta,VolumeDelta,Volume,VWAP,Range,TickCount,TicksPerSec,CumDelta,Session");
        }

        private string BuildFilename()
        {
            DateTime now = Server.Time;
            return string.Format("{0}_{1}min_{2:yyyyMMdd}.csv", Symbol.Name, CandleMinutes, now);
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
