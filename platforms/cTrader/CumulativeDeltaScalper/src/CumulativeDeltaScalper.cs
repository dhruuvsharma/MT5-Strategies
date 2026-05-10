// ===================================================================
//  CumulativeDeltaScalper — cTrader / cAlgo port
//
//  v2 Sniper-mode: tick-level uptick/downtick delta is summed across a
//  sliding window of N candles. Entry on cumulative-delta crossover of
//  ±DeltaThreshold, gated by a 5-confirmation stack:
//    1) momentum alignment (last 3 candles share direction)
//    2) HTF (M15) EMA(50) bid-vs-EMA filter
//    3) HTF EMA slope direction matches signal
//    4) ADX(14) on M15 ≥ threshold (trending regime)
//    5) current spread within rolling-avg multiplier + hard cap
//
//  Session-aware (Asia/London/NY/Overlap, GMT). Risk-based lot sizing
//  on ATR-anchored SL/TP. Fast exits: time-out, adverse-delta flip,
//  optional breakeven. Per-session and daily caps with cooldowns.
//
//  Parity reference: platforms/MT5/CumulativeDeltaScalper/src/*.mq5
// ===================================================================
using System;
using System.Collections.Generic;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    public enum SessionId { None = 0, Asia = 1, London = 2, NewYork = 3, Overlap = 4 }

    [Robot(AccessRights = AccessRights.None, AddIndicators = true, TimeZone = TimeZones.UTC)]
    public class CumulativeDeltaScalper : Robot
    {
        // ============================================================
        //  Config — Delta Settings
        // ============================================================
        [Parameter("Window Size", DefaultValue = 10, MinValue = 2, Group = "Delta")]
        public int WindowSize { get; set; }

        [Parameter("Delta Threshold", DefaultValue = 300, MinValue = 1, Group = "Delta")]
        public int DeltaThreshold { get; set; }

        // ============================================================
        //  Sessions (GMT)
        // ============================================================
        [Parameter("Use Session Filter", DefaultValue = true, Group = "Sessions")]
        public bool UseSessionFilter { get; set; }

        [Parameter("Overlap Only (London/NY)", DefaultValue = true, Group = "Sessions")]
        public bool OverlapOnly { get; set; }

        [Parameter("Overlap Start H", DefaultValue = 12, Group = "Sessions")] public int OverlapStartHour { get; set; }
        [Parameter("Overlap Start M", DefaultValue = 30, Group = "Sessions")] public int OverlapStartMin  { get; set; }
        [Parameter("Overlap End H",   DefaultValue = 16, Group = "Sessions")] public int OverlapEndHour   { get; set; }
        [Parameter("Overlap End M",   DefaultValue = 0,  Group = "Sessions")] public int OverlapEndMin    { get; set; }

        [Parameter("Use Asia",  DefaultValue = false, Group = "Sessions")] public bool UseAsiaSession { get; set; }
        [Parameter("Asia Start H", DefaultValue = 0, Group = "Sessions")] public int AsiaStartHour { get; set; }
        [Parameter("Asia Start M", DefaultValue = 0, Group = "Sessions")] public int AsiaStartMin  { get; set; }
        [Parameter("Asia End H",   DefaultValue = 7, Group = "Sessions")] public int AsiaEndHour   { get; set; }
        [Parameter("Asia End M",   DefaultValue = 0, Group = "Sessions")] public int AsiaEndMin    { get; set; }

        [Parameter("Use London", DefaultValue = true, Group = "Sessions")] public bool UseLondonSession { get; set; }
        [Parameter("London Start H", DefaultValue = 7,  Group = "Sessions")] public int LondonStartHour { get; set; }
        [Parameter("London Start M", DefaultValue = 0,  Group = "Sessions")] public int LondonStartMin  { get; set; }
        [Parameter("London End H",   DefaultValue = 12, Group = "Sessions")] public int LondonEndHour   { get; set; }
        [Parameter("London End M",   DefaultValue = 0,  Group = "Sessions")] public int LondonEndMin    { get; set; }

        [Parameter("Use New York", DefaultValue = true, Group = "Sessions")] public bool UseNewYorkSession { get; set; }
        [Parameter("NY Start H", DefaultValue = 12, Group = "Sessions")] public int NYStartHour { get; set; }
        [Parameter("NY Start M", DefaultValue = 30, Group = "Sessions")] public int NYStartMin  { get; set; }
        [Parameter("NY End H",   DefaultValue = 17, Group = "Sessions")] public int NYEndHour   { get; set; }
        [Parameter("NY End M",   DefaultValue = 0,  Group = "Sessions")] public int NYEndMin    { get; set; }

        // ============================================================
        //  Sniper Filters
        // ============================================================
        [Parameter("Min Confirmations (0..5)", DefaultValue = 5, MinValue = 0, MaxValue = 5, Group = "Sniper")]
        public int MinConfirmations { get; set; }

        [Parameter("EMA Slope Bars", DefaultValue = 3, MinValue = 1, Group = "Sniper")]
        public int EMASlopeBars { get; set; }

        [Parameter("ADX Threshold", DefaultValue = 18.0, MinValue = 0.0, Step = 0.5, Group = "Sniper")]
        public double ADXThreshold { get; set; }

        [Parameter("Spread Avg Multiplier", DefaultValue = 1.5, MinValue = 1.0, Step = 0.1, Group = "Sniper")]
        public double SpreadAvgMultiplier { get; set; }

        [Parameter("Spread History Size", DefaultValue = 30, MinValue = 1, Group = "Sniper")]
        public int SpreadHistorySize { get; set; }

        // ============================================================
        //  Trade Settings
        // ============================================================
        [Parameter("Use Risk-Based Sizing", DefaultValue = true, Group = "Trade")]
        public bool UseRiskBasedSizing { get; set; }

        [Parameter("Risk % per Trade", DefaultValue = 1.0, MinValue = 0.1, Step = 0.1, Group = "Trade")]
        public double RiskPercentPerTrade { get; set; }

        [Parameter("Fixed Lot Size", DefaultValue = 0.01, MinValue = 0.01, Step = 0.01, Group = "Trade")]
        public double FixedLotSize { get; set; }

        [Parameter("Max Lot Size (cap)", DefaultValue = 5.0, MinValue = 0.01, Step = 0.01, Group = "Trade")]
        public double MaxLotSize { get; set; }

        [Parameter("TP Multiplier (×ATR)", DefaultValue = 0.4, MinValue = 0.1, Step = 0.1, Group = "Trade")]
        public double TP_Multiplier { get; set; }

        [Parameter("SL Multiplier (×ATR)", DefaultValue = 0.8, MinValue = 0.1, Step = 0.1, Group = "Trade")]
        public double SL_Multiplier { get; set; }

        [Parameter("Use Breakeven", DefaultValue = false, Group = "Trade")]
        public bool UseBreakeven { get; set; }

        [Parameter("Breakeven Pips", DefaultValue = 1.5, MinValue = 0.1, Step = 0.1, Group = "Trade")]
        public double BreakevenPips { get; set; }

        [Parameter("Max Spread (Points)", DefaultValue = 15, MinValue = 1, Group = "Trade")]
        public int MaxSpreadPoints { get; set; }

        // ============================================================
        //  Fast Exits
        // ============================================================
        [Parameter("Max Trade Seconds", DefaultValue = 90, MinValue = 0, Group = "Fast Exit")]
        public int MaxTradeSeconds { get; set; }

        [Parameter("Adverse Delta Exit", DefaultValue = true, Group = "Fast Exit")]
        public bool AdverseDeltaExit { get; set; }

        [Parameter("Adverse Delta Cooldown (s)", DefaultValue = 5, MinValue = 0, Group = "Fast Exit")]
        public int AdverseDeltaCooldown { get; set; }

        // ============================================================
        //  Filters
        // ============================================================
        [Parameter("Use HTF EMA Filter", DefaultValue = true, Group = "Filters")]
        public bool UseHTFFilter { get; set; }

        [Parameter("Min ATR", DefaultValue = 0.00030, MinValue = 0.0, Step = 0.00005, Group = "Filters")]
        public double MinATR { get; set; }

        [Parameter("Max ATR", DefaultValue = 0.00200, MinValue = 0.0, Step = 0.00005, Group = "Filters")]
        public double MaxATR { get; set; }

        // ============================================================
        //  Risk Management
        // ============================================================
        [Parameter("Max Trades / Session", DefaultValue = 2, MinValue = 1, Group = "Risk")]
        public int MaxTradesPerSession { get; set; }

        [Parameter("Max Daily Trades", DefaultValue = 3, MinValue = 1, Group = "Risk")]
        public int MaxDailyTrades { get; set; }

        [Parameter("Max Daily Loss %", DefaultValue = 2.0, MinValue = 0.1, Step = 0.1, Group = "Risk")]
        public double MaxDailyLossPercent { get; set; }

        [Parameter("Min Sec Between Trades", DefaultValue = 900, MinValue = 0, Group = "Risk")]
        public int MinSecondsBetweenTrades { get; set; }

        [Parameter("Loss Cooldown Min", DefaultValue = 15, MinValue = 0, Group = "Risk")]
        public int LossCooldownMinutes { get; set; }

        [Parameter("Stop After First Win", DefaultValue = true, Group = "Risk")]
        public bool StopAfterFirstWin { get; set; }

        [Parameter("Stop After First Loss", DefaultValue = true, Group = "Risk")]
        public bool StopAfterFirstLoss { get; set; }

        // ============================================================
        //  Identity
        // ============================================================
        [Parameter("Order Label", DefaultValue = "CDScalper", Group = "Identity")]
        public string TradeLabel { get; set; }

        // ============================================================
        //  Constants
        // ============================================================
        private const string Prefix = "[CDScalper-cT] ";
        private const double BreakevenBufferPips = 0.5;
        private const int    AtrPeriod = 14;
        private const int    EmaPeriod = 50;
        private const int    AdxPeriod = 14;

        // ============================================================
        //  Indicators
        // ============================================================
        private AverageTrueRange _atr;
        private ExponentialMovingAverage _htfEma;
        private DirectionalMovementSystem _htfDms;

        // ============================================================
        //  Tick / candle delta state
        // ============================================================
        private double _prevBid;
        private int _uptickCount;
        private int _downtickCount;
        private int _liveDelta;

        // Circular delta buffer
        private int[] _deltaBuffer;
        private int _bufferIndex;
        private int _bufferFilled;
        private int _prevCumDelta;

        // Spread history (per-bar samples)
        private int[] _spreadHistory;
        private int _spreadHistoryIdx;
        private int _spreadHistoryFilled;

        // ============================================================
        //  Daily / session tracking
        // ============================================================
        private int    _dailyTradeCount;
        private double _dailyPnL;
        private double _dayStartBalance;
        private DateTime _lastTradeDay = DateTime.MinValue;

        private DateTime _lastLossTime  = DateTime.MinValue;
        private DateTime _lastTradeTime = DateTime.MinValue;

        private SessionId _currentSession = SessionId.None;
        private int _sessionTradeCount;
        private int _sessionWins;
        private int _sessionLosses;

        // Open trade tracking
        private DateTime _openTradeTime  = DateTime.MinValue;
        private int      _openTradeDir   = 0; // +1 buy, -1 sell, 0 none
        private bool     _breakevenApplied;

        // ============================================================
        //  Lifecycle
        // ============================================================
        protected override void OnStart()
        {
            // Validate
            if (WindowSize < 2)              { Print(Prefix + "WindowSize must be >= 2"); Stop(); return; }
            if (DeltaThreshold <= 0)         { Print(Prefix + "DeltaThreshold must be > 0"); Stop(); return; }
            if (SL_Multiplier <= 0 || TP_Multiplier <= 0) { Print(Prefix + "SL/TP mult must be > 0"); Stop(); return; }

            _atr = Indicators.AverageTrueRange(AtrPeriod, MovingAverageType.Simple);

            var htfBars = MarketData.GetBars(TimeFrame.Minute15);
            _htfEma = Indicators.ExponentialMovingAverage(htfBars.ClosePrices, EmaPeriod);
            _htfDms = Indicators.DirectionalMovementSystem(htfBars, AdxPeriod);

            _deltaBuffer    = new int[WindowSize];
            _spreadHistory  = new int[SpreadHistorySize];

            _prevBid = Symbol.Bid;
            _dayStartBalance = Account.Balance;

            // Position close hook for session W/L + last-loss timer
            Positions.Closed += OnOurPositionClosed;

            Print(Prefix + "Initialised. Window=" + WindowSize
                + " Threshold=" + DeltaThreshold
                + " MinConf=" + MinConfirmations
                + " Label=" + TradeLabel);
        }

        protected override void OnStop()
        {
            Positions.Closed -= OnOurPositionClosed;
            Print(Prefix + "Stopped");
        }

        protected override void OnTick()
        {
            // Daily / session bookkeeping (cheap, run every tick)
            ResetDailyCounters();
            UpdateSessionState();
            SyncDailyStatsFromHistory();

            ProcessTickDelta();

            if (HasOpenPosition())
            {
                ManageOpenTrade();
                return;
            }

            // Guards before signal eval
            if (!CheckAllGuards(out string _)) return;

            int signal = CheckSniperSignal();
            if (signal == 0) return;

            OpenTrade(signal);
        }

        protected override void OnBar()
        {
            FinalizeCandle();
        }

        // ============================================================
        //  Tick / candle delta
        // ============================================================
        private void ProcessTickDelta()
        {
            double bid = Symbol.Bid;
            if (bid > _prevBid) _uptickCount++;
            else if (bid < _prevBid) _downtickCount++;
            _prevBid = bid;
            _liveDelta = _uptickCount - _downtickCount;
        }

        private void FinalizeCandle()
        {
            int candleDelta = _uptickCount - _downtickCount;

            _deltaBuffer[_bufferIndex] = candleDelta;
            _bufferIndex = (_bufferIndex + 1) % WindowSize;
            if (_bufferFilled < WindowSize) _bufferFilled++;

            // Sample spread once per bar (in points)
            int spread = SpreadInPoints();
            _spreadHistory[_spreadHistoryIdx] = spread;
            _spreadHistoryIdx = (_spreadHistoryIdx + 1) % SpreadHistorySize;
            if (_spreadHistoryFilled < SpreadHistorySize) _spreadHistoryFilled++;

            _uptickCount = 0;
            _downtickCount = 0;
            _liveDelta = 0;

            Print(Prefix + "Candle closed. Delta=" + candleDelta + " Spread=" + spread);
        }

        private int CalculateCumDelta()
        {
            int sum = 0;
            int count = Math.Min(_bufferFilled, WindowSize);
            for (int i = 0; i < count; i++)
                sum += _deltaBuffer[i];
            return sum;
        }

        // Returns deltas in chronological order: oldest → newest, length = filled count
        private int[] GetOrderedDeltas()
        {
            int count = Math.Min(_bufferFilled, WindowSize);
            int[] result = new int[count];
            int start = (_bufferFilled >= WindowSize) ? _bufferIndex : 0;
            for (int i = 0; i < count; i++)
                result[i] = _deltaBuffer[(start + i) % WindowSize];
            return result;
        }

        // ============================================================
        //  Signal layer
        // ============================================================
        // Returns +1/-1 on cumulative-delta crossover of ±threshold; 0 otherwise.
        private int DeltaCrossover()
        {
            if (_bufferFilled < WindowSize) return 0;

            int cum = CalculateCumDelta();
            int prev = _prevCumDelta;
            _prevCumDelta = cum;

            if (prev <=  DeltaThreshold && cum >  DeltaThreshold) return  1;
            if (prev >= -DeltaThreshold && cum < -DeltaThreshold) return -1;
            return 0;
        }

        private bool CheckMomentumAlignment(int signal)
        {
            int[] deltas = GetOrderedDeltas();
            if (deltas.Length < 3) return false;
            for (int i = deltas.Length - 3; i < deltas.Length; i++)
            {
                if (signal > 0 && deltas[i] <= 0) return false;
                if (signal < 0 && deltas[i] >= 0) return false;
            }
            return true;
        }

        private bool CheckHTFEMA(int signal)
        {
            if (!UseHTFFilter) return true;
            double ema = _htfEma.Result.LastValue;
            if (ema == 0) return false;
            double bid = Symbol.Bid;
            return signal > 0 ? bid > ema : bid < ema;
        }

        private bool CheckEMASlope(int signal)
        {
            int slopeBars = Math.Max(EMASlopeBars, 1);
            int last = _htfEma.Result.Count - 1;
            if (last < slopeBars) return false;
            double newest = _htfEma.Result[last];
            double oldest = _htfEma.Result[last - slopeBars];
            int slope = newest > oldest ? 1 : (newest < oldest ? -1 : 0);
            return signal > 0 ? slope > 0 : (signal < 0 && slope < 0);
        }

        private bool CheckADXTrending()
        {
            return _htfDms.ADX.LastValue >= ADXThreshold;
        }

        private bool CheckSpreadDynamic()
        {
            int spread = SpreadInPoints();
            if (spread > MaxSpreadPoints) return false;
            double avg = AvgSpreadPoints();
            if (avg <= 0) return true; // bootstrap
            return spread <= avg * SpreadAvgMultiplier;
        }

        private int CheckSniperSignal()
        {
            int signal = DeltaCrossover();
            if (signal == 0) return 0;

            int conf = 0;
            if (CheckMomentumAlignment(signal)) conf++;
            if (CheckHTFEMA(signal))            conf++;
            if (CheckEMASlope(signal))          conf++;
            if (CheckADXTrending())             conf++;
            if (CheckSpreadDynamic())           conf++;

            if (conf < MinConfirmations)
            {
                Print(Prefix + "Signal rejected dir=" + signal + " conf=" + conf + "/5 (need " + MinConfirmations + ")");
                return 0;
            }
            Print(Prefix + "SNIPER " + (signal > 0 ? "BUY" : "SELL") + " conf=" + conf + "/5");
            return signal;
        }

        // ============================================================
        //  Sessions / Guards
        // ============================================================
        private int MinutesSinceMidnightGmt()
        {
            DateTime utc = Server.Time.ToUniversalTime();
            return utc.Hour * 60 + utc.Minute;
        }

        private static bool InRange(int total, int sH, int sM, int eH, int eM)
        {
            int s = sH * 60 + sM;
            int e = eH * 60 + eM;
            return total >= s && total < e;
        }

        private SessionId GetCurrentSessionId()
        {
            int t = MinutesSinceMidnightGmt();
            if (OverlapOnly)
            {
                if (InRange(t, OverlapStartHour, OverlapStartMin, OverlapEndHour, OverlapEndMin)) return SessionId.Overlap;
                return SessionId.None;
            }
            if (UseAsiaSession    && InRange(t, AsiaStartHour,   AsiaStartMin,   AsiaEndHour,   AsiaEndMin))   return SessionId.Asia;
            if (UseLondonSession  && InRange(t, LondonStartHour, LondonStartMin, LondonEndHour, LondonEndMin)) return SessionId.London;
            if (UseNewYorkSession && InRange(t, NYStartHour,     NYStartMin,     NYEndHour,     NYEndMin))     return SessionId.NewYork;
            return SessionId.None;
        }

        private void UpdateSessionState()
        {
            SessionId s = GetCurrentSessionId();
            if (s != _currentSession)
            {
                _sessionTradeCount = 0;
                _sessionWins       = 0;
                _sessionLosses     = 0;
                _currentSession    = s;
                Print(Prefix + "Session → " + s);
            }
        }

        private bool CheckAllGuards(out string reason)
        {
            reason = "";
            if (UseSessionFilter && GetCurrentSessionId() == SessionId.None) { reason = "SESSION CLOSED"; return false; }

            int spread = SpreadInPoints();
            if (spread > MaxSpreadPoints) { reason = "SPREAD HIGH (" + spread + ">" + MaxSpreadPoints + ")"; return false; }

            if (_dailyTradeCount    >= MaxDailyTrades)      { reason = "DAILY LIMIT";   return false; }
            if (_sessionTradeCount  >= MaxTradesPerSession) { reason = "SESSION LIMIT"; return false; }
            if (StopAfterFirstWin   && _sessionWins   >= 1) { reason = "POST-WIN HALT"; return false; }
            if (StopAfterFirstLoss  && _sessionLosses >= 1) { reason = "POST-LOSS HALT"; return false; }

            if (_dayStartBalance > 0)
            {
                double maxLoss = _dayStartBalance * MaxDailyLossPercent / 100.0;
                if (_dailyPnL < -maxLoss) { reason = "DAILY LOSS LIMIT"; return false; }
            }

            DateTime now = Server.Time;
            if (_lastTradeTime != DateTime.MinValue && now < _lastTradeTime.AddSeconds(MinSecondsBetweenTrades))
            { reason = "INTER-TRADE COOLDOWN"; return false; }
            if (_lastLossTime != DateTime.MinValue && now < _lastLossTime.AddMinutes(LossCooldownMinutes))
            { reason = "LOSS COOLDOWN"; return false; }

            double atr = _atr.Result.LastValue;
            if (atr < MinATR) { reason = "ATR LOW"; return false; }
            if (atr > MaxATR) { reason = "ATR HIGH"; return false; }

            reason = "ACTIVE " + _currentSession;
            return true;
        }

        // ============================================================
        //  Risk / Stop distances / Lot sizing
        // ============================================================
        private double CalcSLDistancePrice() { return _atr.Result.LastValue * SL_Multiplier; }
        private double CalcTPDistancePrice() { return _atr.Result.LastValue * TP_Multiplier; }

        private double CalcLotsToUnits()
        {
            if (!UseRiskBasedSizing)
                return Symbol.NormalizeVolumeInUnits(Symbol.QuantityToVolumeInUnits(Math.Min(FixedLotSize, MaxLotSize)));

            double riskAmt = Account.Balance * RiskPercentPerTrade / 100.0;
            double slPriceDist = CalcSLDistancePrice();
            if (slPriceDist <= 0 || Symbol.TickValue <= 0 || Symbol.TickSize <= 0)
                return Symbol.NormalizeVolumeInUnits(Symbol.QuantityToVolumeInUnits(FixedLotSize));

            // loss per 1 unit at slPriceDist = (slPriceDist / TickSize) * TickValue
            double lossPerUnit = (slPriceDist / Symbol.TickSize) * Symbol.TickValue;
            if (lossPerUnit <= 0)
                return Symbol.NormalizeVolumeInUnits(Symbol.QuantityToVolumeInUnits(FixedLotSize));

            double units = riskAmt / lossPerUnit;
            // Cap by MaxLotSize
            double maxUnits = Symbol.QuantityToVolumeInUnits(MaxLotSize);
            if (units > maxUnits) units = maxUnits;
            return Symbol.NormalizeVolumeInUnits(units);
        }

        private int SpreadInPoints()
        {
            // Symbol.Spread is in price units; convert to points.
            return (int)Math.Round(Symbol.Spread / Symbol.TickSize);
        }

        private double AvgSpreadPoints()
        {
            if (_spreadHistoryFilled <= 0) return 0;
            long sum = 0;
            for (int i = 0; i < _spreadHistoryFilled; i++) sum += _spreadHistory[i];
            return (double)sum / _spreadHistoryFilled;
        }

        // ============================================================
        //  Trade layer
        // ============================================================
        private bool HasOpenPosition()
        {
            return Positions.Any(p => p.SymbolName == Symbol.Name && p.Label == TradeLabel);
        }

        private void OpenTrade(int direction)
        {
            double slPriceDist = CalcSLDistancePrice();
            double tpPriceDist = CalcTPDistancePrice();
            if (slPriceDist <= 0 || tpPriceDist <= 0)
            {
                Print(Prefix + "Invalid SL/TP distances");
                return;
            }

            double slPips = slPriceDist / Symbol.PipSize;
            double tpPips = tpPriceDist / Symbol.PipSize;
            double units  = CalcLotsToUnits();
            if (units <= 0) { Print(Prefix + "Lot=0, skip"); return; }

            TradeType tt = direction > 0 ? TradeType.Buy : TradeType.Sell;
            var res = ExecuteMarketOrder(tt, Symbol.Name, units, TradeLabel, slPips, tpPips);
            if (!res.IsSuccessful)
            {
                Print(Prefix + "Open failed dir=" + direction + " err=" + res.Error);
                return;
            }

            _breakevenApplied = false;
            _lastTradeTime = Server.Time;
            _openTradeTime = Server.Time;
            _openTradeDir  = direction;
            _sessionTradeCount++;
            Print(Prefix + (direction > 0 ? "BUY" : "SELL") + " opened. units=" + units
                + " slPips=" + slPips.ToString("F1") + " tpPips=" + tpPips.ToString("F1")
                + " session=" + _currentSession);
        }

        private void ManageOpenTrade()
        {
            var pos = Positions.FirstOrDefault(p => p.SymbolName == Symbol.Name && p.Label == TradeLabel);
            if (pos == null)
            {
                _openTradeDir = 0;
                _openTradeTime = DateTime.MinValue;
                return;
            }

            // Time exit
            if (MaxTradeSeconds > 0 && _openTradeTime != DateTime.MinValue
                && Server.Time >= _openTradeTime.AddSeconds(MaxTradeSeconds))
            {
                ClosePos(pos, "TIME_EXIT");
                return;
            }

            // Adverse delta exit
            if (AdverseDeltaExit && _openTradeTime != DateTime.MinValue
                && (Server.Time - _openTradeTime).TotalSeconds >= AdverseDeltaCooldown)
            {
                int cum = CalculateCumDelta();
                bool adverse = (_openTradeDir > 0 && cum < -DeltaThreshold)
                            || (_openTradeDir < 0 && cum >  DeltaThreshold);
                if (adverse) { ClosePos(pos, "ADVERSE_DELTA"); return; }
            }

            // Breakeven
            if (UseBreakeven && !_breakevenApplied)
                TryBreakeven(pos);
        }

        private void ClosePos(Position pos, string reason)
        {
            var res = ClosePosition(pos);
            if (res.IsSuccessful)
            {
                Print(Prefix + "Position closed. reason=" + reason);
                _openTradeDir = 0;
                _openTradeTime = DateTime.MinValue;
            }
            else
            {
                Print(Prefix + "Close failed err=" + res.Error);
            }
        }

        private void TryBreakeven(Position pos)
        {
            double pipSize = Symbol.PipSize;
            double openPx  = pos.EntryPrice;
            double curSL   = pos.StopLoss ?? 0;
            double? curTP  = pos.TakeProfit;
            double beBuf   = BreakevenBufferPips * pipSize;

            if (pos.TradeType == TradeType.Buy)
            {
                double profitPips = (Symbol.Bid - openPx) / pipSize;
                if (profitPips < BreakevenPips) return;
                double newSL = openPx + beBuf;
                if (newSL > curSL)
                {
                    var res = ModifyPosition(pos, newSL, curTP);
                    if (res.IsSuccessful) { _breakevenApplied = true; Print(Prefix + "BE applied SL=" + newSL); }
                }
            }
            else
            {
                double profitPips = (openPx - Symbol.Ask) / pipSize;
                if (profitPips < BreakevenPips) return;
                double newSL = openPx - beBuf;
                if (curSL == 0 || newSL < curSL)
                {
                    var res = ModifyPosition(pos, newSL, curTP);
                    if (res.IsSuccessful) { _breakevenApplied = true; Print(Prefix + "BE applied SL=" + newSL); }
                }
            }
        }

        // ============================================================
        //  Daily reset + history sync + position-close hook
        // ============================================================
        private void ResetDailyCounters()
        {
            DateTime today = Server.Time.Date;
            if (_lastTradeDay != today)
            {
                _lastTradeDay     = today;
                _dayStartBalance  = Account.Balance;
                _dailyTradeCount  = 0;
                _dailyPnL         = 0.0;
                SyncDailyStatsFromHistory();
                Print(Prefix + "New trading day. Balance=" + _dayStartBalance + " synced trades=" + _dailyTradeCount);
            }
        }

        private void SyncDailyStatsFromHistory()
        {
            DateTime dayStart = Server.Time.Date;
            double pnl = 0;
            int count  = 0;

            // History contains closed deals; filter by our label, symbol and time
            foreach (var h in History)
            {
                if (h.SymbolName != Symbol.Name) continue;
                if (h.Label != TradeLabel) continue;
                if (h.ClosingTime < dayStart) continue;
                pnl += h.NetProfit; // already includes commission/swap in cAlgo
                count++;
            }

            // Plus any open positions opened today
            foreach (var p in Positions.Where(p => p.SymbolName == Symbol.Name && p.Label == TradeLabel))
            {
                if (p.EntryTime >= dayStart) count++;
            }

            _dailyPnL = pnl;
            _dailyTradeCount = count;
        }

        private void OnOurPositionClosed(PositionClosedEventArgs args)
        {
            var p = args.Position;
            if (p.SymbolName != Symbol.Name) return;
            if (p.Label != TradeLabel) return;

            double profit = p.NetProfit;
            if (profit > 0) _sessionWins++;
            else if (profit < 0)
            {
                _sessionLosses++;
                _lastLossTime = Server.Time;
            }
            _openTradeDir  = 0;
            _openTradeTime = DateTime.MinValue;
            Print(Prefix + "Exit P&L=" + profit + " session W/L=" + _sessionWins + "/" + _sessionLosses);
        }
    }
}
