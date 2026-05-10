// ===================================================================
//  ApexScalper — cTrader / cAlgo SCAFFOLD (WIP)
//
//  This is a structural port of the MT5 ApexScalper. The directory
//  layout mirrors the MT5 EA (Core / Signals / Engine / Execution /
//  Risk / Utils / UI / Logging). All 8 order-flow signals are present
//  as classes implementing ISignal but RETURN 0.0 from Evaluate() —
//  i.e. the scaffold will compile, run, and place no trades.
//
//  TO COMPLETE THE PORT:
//    1. Implement each signal's Evaluate() method (see .cs file in
//       Signals/) using cAlgo APIs:
//         - Bars.TickVolumes  for volume series
//         - MarketDepth       for OBI (Symbol.MarketDepth)
//         - Indicators.*      for ADX, BB, ATR, EMA
//    2. Implement ConflictFilter top-2-weight check
//    3. Implement RegimeClassifier ADX + BB-width + VPOC
//    4. Implement TradeManager.OpenPosition + StopLossEngine
//
//  Full strategy reference:
//    platforms/MT5/ApexScalper/README.md
//    platforms/MT5/ApexScalper/MEMORY.md (file registry)
//
//  Parity reference for math: each MT5 signal's .mqh file in
//    platforms/MT5/ApexScalper/Signals/
// ===================================================================
using System;
using System.Collections.Generic;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;
using ApexScalper.Engine;
using ApexScalper.Risk;
using ApexScalper.Signals;
using ApexScalper.Execution;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None, AddIndicators = true, TimeZone = TimeZones.UTC)]
    public class ApexScalper : Robot
    {
        // ============================================================
        //  Inputs (selected core set — full MT5 input list TBD)
        // ============================================================
        [Parameter("Order Label", DefaultValue = "ApexScalper")]
        public string TradeLabel { get; set; }

        [Parameter("Composite Threshold (|score|)", DefaultValue = 1.5, MinValue = 0.5, Step = 0.1)]
        public double CompositeThreshold { get; set; }

        [Parameter("Min Agreeing Signals", DefaultValue = 4, MinValue = 1, MaxValue = 8)]
        public int MinAgreeingSignals { get; set; }

        [Parameter("Risk % per Trade", DefaultValue = 0.5, MinValue = 0.1, Step = 0.1)]
        public double RiskPercent { get; set; }

        [Parameter("Max Spread (Points)", DefaultValue = 30, MinValue = 1)]
        public int MaxSpreadPoints { get; set; }

        // -- Per-signal weights (mirror MT5 defaults) --
        [Parameter("Weight: Cumulative Delta", DefaultValue = 0.20, MinValue = 0, MaxValue = 1, Step = 0.05, Group = "Weights")]
        public double WeightDelta { get; set; }
        [Parameter("Weight: VPIN", DefaultValue = 0.20, MinValue = 0, MaxValue = 1, Step = 0.05, Group = "Weights")]
        public double WeightVPIN { get; set; }
        [Parameter("Weight: OBI Shallow", DefaultValue = 0.15, MinValue = 0, MaxValue = 1, Step = 0.05, Group = "Weights")]
        public double WeightOBIShallow { get; set; }
        [Parameter("Weight: Footprint Imbalance", DefaultValue = 0.15, MinValue = 0, MaxValue = 1, Step = 0.05, Group = "Weights")]
        public double WeightFootprint { get; set; }
        [Parameter("Weight: Absorption", DefaultValue = 0.10, MinValue = 0, MaxValue = 1, Step = 0.05, Group = "Weights")]
        public double WeightAbsorption { get; set; }
        [Parameter("Weight: OBI Deep", DefaultValue = 0.10, MinValue = 0, MaxValue = 1, Step = 0.05, Group = "Weights")]
        public double WeightOBIDeep { get; set; }
        [Parameter("Weight: Tape Speed", DefaultValue = 0.05, MinValue = 0, MaxValue = 1, Step = 0.05, Group = "Weights")]
        public double WeightTapeSpeed { get; set; }
        [Parameter("Weight: HVP Slope", DefaultValue = 0.05, MinValue = 0, MaxValue = 1, Step = 0.05, Group = "Weights")]
        public double WeightHVP { get; set; }

        // ============================================================
        //  State
        // ============================================================
        private const string Prefix = "[ApexScalper-cT-WIP] ";

        private List<ISignal> _signals;
        private ScoringEngine _scoring;
        private RegimeClassifier _regime;
        private ConflictFilter _conflict;
        private RiskManager _risk;
        private TradeManager _trade;

        protected override void OnStart()
        {
            _signals = new List<ISignal>
            {
                new DeltaSignal(this)        { Weight = WeightDelta      },
                new VPINSignal(this)         { Weight = WeightVPIN       },
                new OBIShallowSignal(this)   { Weight = WeightOBIShallow },
                new FootprintSignal(this)    { Weight = WeightFootprint  },
                new AbsorptionSignal(this)   { Weight = WeightAbsorption },
                new OBIDeepSignal(this)      { Weight = WeightOBIDeep    },
                new TapeSpeedSignal(this)    { Weight = WeightTapeSpeed  },
                new HVPSlopeSignal(this)     { Weight = WeightHVP        },
            };

            _scoring  = new ScoringEngine(_signals);
            _regime   = new RegimeClassifier(this);
            _conflict = new ConflictFilter();
            _risk     = new RiskManager(this) { RiskPercent = RiskPercent, MaxSpreadPoints = MaxSpreadPoints };
            _trade    = new TradeManager(this) { Label = TradeLabel };

            Print(Prefix + "SCAFFOLD initialised — signal evaluations stubbed; no trades will be placed until signals are implemented.");
            Print(Prefix + "See platforms/MT5/ApexScalper/README.md for the spec to mirror.");
        }

        protected override void OnTick()
        {
            // Per-signal evaluation
            foreach (var s in _signals) s.Update();

            // Skip if any safety guard fails (spread, session, daily limits)
            if (!_risk.AllowEntry(out string reason)) return;

            // Compose
            double composite = _scoring.Composite();
            int agreeing = _scoring.AgreeingCount(composite);

            // Conflict on top-weighted signals (Delta vs VPIN by default)
            if (_conflict.HasConflict(_signals, composite, threshold: CompositeThreshold)) return;

            if (Math.Abs(composite) < CompositeThreshold) return;
            if (agreeing < MinAgreeingSignals) return;

            // Apply regime weight modulation (currently a passthrough until classifier is implemented)
            composite *= _regime.WeightMultiplier(composite);

            int direction = composite > 0 ? 1 : -1;
            _trade.OpenPosition(direction);
        }

        protected override void OnStop()
        {
            Print(Prefix + "Stopped");
        }
    }
}
