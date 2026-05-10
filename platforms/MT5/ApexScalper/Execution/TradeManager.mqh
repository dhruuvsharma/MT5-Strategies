//+------------------------------------------------------------------+
//| TradeManager.mqh — APEX_SCALPER                                  |
//| CTrade wrapper with full pre-submission validation, one requote  |
//| retry, TradeContext population, and error logging.              |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"

//--- Forward declaration (PositionTracker is included after TradeManager)
class CPositionTracker;

class CTradeManager
{
private:
    CTrade           m_trade;
    CPositionTracker *m_tracker;   // set via SetTracker()
    double           m_point;
    int              m_digits;

    // Validate all order parameters before submission; returns false with reason
    bool validate(int direction, double lot, double entry,
                  double sl, double tp, string &reason) const
    {
        if(direction != 1 && direction != -1)
            { reason = "invalid direction"; return false; }
        if(lot < SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN))
            { reason = "lot below minimum"; return false; }
        if(lot > SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX))
            { reason = "lot above maximum"; return false; }
        double min_stop = (double)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL)
                        * m_point;
        if(sl > 0.0 && MathAbs(entry - sl) < min_stop)
            { reason = StringFormat("SL too close (%.5f < %.5f)", MathAbs(entry - sl), min_stop); return false; }
        if(tp > 0.0 && MathAbs(entry - tp) < min_stop)
            { reason = StringFormat("TP too close (%.5f < %.5f)", MathAbs(entry - tp), min_stop); return false; }
        if(entry <= 0.0)
            { reason = "invalid entry price"; return false; }
        return true;
    }

    // Round lot to valid step
    double normalize_lot(double raw_lot) const
    {
        double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
        if(step < 1e-10) step = 0.01;
        double lot = MathFloor(raw_lot / step) * step;
        lot = MathMax(lot, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN));
        lot = MathMin(lot, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX));
        return NormalizeDouble(lot, 2);
    }

public:
    bool Initialize()
    {
        m_point   = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        m_digits  = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
        m_tracker = NULL;
        m_trade.SetExpertMagicNumber(InpMagicNumber);
        m_trade.SetDeviationInPoints(InpSlippage);
        m_trade.SetTypeFilling(ORDER_FILLING_IOC);
        return (m_point > 0.0);
    }

    // Inject PositionTracker once it is initialized (avoids circular include)
    void SetTracker(CPositionTracker *tracker) { m_tracker = tracker; }

    // Open a market position. Returns the ticket on success, 0 on failure.
    ulong OpenPosition(int direction, double lot, double sl, double tp,
                       const CompositeResult &context)
    {
        lot = normalize_lot(lot);

        // Get current market price
        double entry = (direction == 1)
                       ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                       : SymbolInfoDouble(Symbol(), SYMBOL_BID);
        entry = NormalizeDouble(entry, m_digits);

        string reason;
        if(!validate(direction, lot, entry, sl, tp, reason))
        {
            PrintFormat("APEX TradeManager: validation failed — %s", reason);
            return 0;
        }

        ENUM_ORDER_TYPE order_type = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        bool sent = m_trade.PositionOpen(Symbol(), order_type, lot, entry, sl, tp,
                                         InpComment);

        // One requote retry with refreshed price
        if(!sent && m_trade.ResultRetcode() == TRADE_RETCODE_REQUOTE)
        {
            entry = (direction == 1)
                    ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                    : SymbolInfoDouble(Symbol(), SYMBOL_BID);
            entry = NormalizeDouble(entry, m_digits);
            sent  = m_trade.PositionOpen(Symbol(), order_type, lot, entry, sl, tp,
                                          InpComment);
        }

        if(!sent || m_trade.ResultRetcode() != TRADE_RETCODE_DONE)
        {
            PrintFormat("APEX TradeManager: order failed retcode=%d desc=%s",
                        m_trade.ResultRetcode(), m_trade.ResultComment());
            return 0;
        }

        ulong ticket = m_trade.ResultOrder();
        if(ticket == 0) return 0;

        // Populate TradeContext and register with PositionTracker
        TradeContext ctx;
        ZeroMemory(ctx);
        ctx.ticket          = ticket;
        ctx.type            = order_type;
        ctx.entry_price     = entry;
        ctx.sl              = sl;
        ctx.tp              = tp;
        ctx.lot_size        = lot;
        ctx.signal_context  = context;
        ctx.open_time       = TimeCurrent();
        ctx.regime          = g_RegimeString;
        ctx.spread_at_entry = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * m_point;
        ctx.trailing_active = false;

        if(m_tracker != NULL) register_trade(ctx);

        g_TotalTrades++;
        g_BarsSinceLastTrade = 0;

        PrintFormat("APEX TradeManager: opened %s lot=%.2f entry=%.5f sl=%.5f tp=%.5f ticket=%I64u",
                    (direction == 1) ? "BUY" : "SELL", lot, entry, sl, tp, ticket);
        return ticket;
    }

    // Close a position by ticket. Returns true on success.
    bool ClosePosition(ulong ticket)
    {
        if(!PositionSelectByTicket(ticket)) return false;
        bool ok = m_trade.PositionClose(ticket, InpSlippage);
        if(!ok)
            PrintFormat("APEX TradeManager: close failed ticket=%I64u retcode=%d",
                        ticket, m_trade.ResultRetcode());
        return ok;
    }

    // Modify SL and/or TP on an open position. Returns true on success.
    bool ModifyPosition(ulong ticket, double new_sl, double new_tp)
    {
        if(!PositionSelectByTicket(ticket)) return false;
        bool ok = m_trade.PositionModify(ticket, new_sl, new_tp);
        if(!ok)
            PrintFormat("APEX TradeManager: modify failed ticket=%I64u retcode=%d",
                        ticket, m_trade.ResultRetcode());
        return ok;
    }

    // Access the last trade result retcode (for logging layer)
    uint LastRetcode() const { return m_trade.ResultRetcode(); }

private:
    // Forward declaration implementation — defined after PositionTracker is known
    void register_trade(const TradeContext &ctx);
};
