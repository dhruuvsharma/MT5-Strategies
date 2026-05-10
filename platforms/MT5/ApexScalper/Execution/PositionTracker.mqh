//+------------------------------------------------------------------+
//| PositionTracker.mqh — APEX_SCALPER                               |
//| Maintains open TradeContext list (max InpMaxOpenPositions).     |
//| Manages trailing stops after first HVP hit.                    |
//| Handles early exit on composite score reversal.                |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "TradeManager.mqh"
#include "TakeProfitEngine.mqh"

class CPositionTracker
{
private:
    TradeContext     m_contexts[APEX_MAX_OPEN_POSITIONS];
    int              m_count;
    CTradeManager   *m_trade_mgr;
    CTakeProfitEngine *m_tp_engine;

    // Find context index by ticket; returns -1 if not found
    int find_idx(ulong ticket) const
    {
        for(int i = 0; i < m_count; i++)
            if(m_contexts[i].ticket == ticket) return i;
        return -1;
    }

    // Remove context at index (shift array down)
    void remove_idx(int idx)
    {
        for(int i = idx; i < m_count - 1; i++)
            m_contexts[i] = m_contexts[i + 1];
        if(m_count > 0) m_count--;
    }

    // Check if a position is still open in the terminal
    bool position_exists(ulong ticket) const
    {
        return PositionSelectByTicket(ticket);
    }

    // Check if trailing should activate: price has crossed the first TP HVP level
    bool should_activate_trailing(const TradeContext &ctx) const
    {
        if(!InpTPTrailingAfterHVP || ctx.trailing_active) return false;
        double cur = (ctx.type == ORDER_TYPE_BUY)
                     ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                     : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        if(ctx.type == ORDER_TYPE_BUY  && cur >= ctx.tp) return true;
        if(ctx.type == ORDER_TYPE_SELL && cur <= ctx.tp) return true;
        return false;
    }

    // Early exit: composite score strongly reversed against the trade
    bool should_early_exit(const TradeContext &ctx) const
    {
        if(g_LastComposite.timestamp == 0) return false;
        int trade_dir = (ctx.type == ORDER_TYPE_BUY) ? 1 : -1;
        // Strong reversal = composite direction flipped AND score exceeds threshold
        return (g_LastComposite.direction != trade_dir &&
                g_LastComposite.direction != 0 &&
                MathAbs(g_LastComposite.score) >= InpCompositeThreshold &&
                g_LastComposite.trade_allowed);
    }

public:
    bool Initialize(CTradeManager *tm, CTakeProfitEngine *tp)
    {
        if(tm == NULL || tp == NULL) return false;
        m_trade_mgr = tm;
        m_tp_engine = tp;
        m_count     = 0;
        return true;
    }

    // Register a newly opened trade (called by TradeManager)
    void RegisterTrade(const TradeContext &ctx)
    {
        if(m_count >= APEX_MAX_OPEN_POSITIONS) return;
        m_contexts[m_count++] = ctx;
    }

    // Call every tick: manage trailing, early exit, sync closed positions
    void OnTick()
    {
        for(int i = m_count - 1; i >= 0; i--)
        {
            // Sync: remove positions closed externally (SL/TP hit, manual close)
            if(!position_exists(m_contexts[i].ticket))
            {
                // Record stats
                if(PositionSelectByTicket(m_contexts[i].ticket))
                {
                    // Still in history — check final P&L
                }
                // Update g_WinningTrades in Session 12 via TradeLogger
                remove_idx(i);
                continue;
            }

            // Check trailing activation
            if(should_activate_trailing(m_contexts[i]))
            {
                m_contexts[i].trailing_active = true;
                // Reset TP to 0 (now fully trailing managed)
                m_trade_mgr.ModifyPosition(m_contexts[i].ticket, m_contexts[i].sl, 0.0);
            }

            // Apply trailing stop
            if(m_contexts[i].trailing_active)
            {
                double cur_bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
                double cur_ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
                double new_sl  = 0.0;

                if(m_contexts[i].type == ORDER_TYPE_BUY)
                    new_sl = m_tp_engine.ComputeTrailLong(cur_bid, m_contexts[i].sl);
                else
                    new_sl = m_tp_engine.ComputeTrailShort(cur_ask, m_contexts[i].sl);

                if(new_sl > 0.0 && m_trade_mgr.ModifyPosition(m_contexts[i].ticket, new_sl, 0.0))
                    m_contexts[i].sl = new_sl;
            }

            // Early exit on composite reversal
            if(should_early_exit(m_contexts[i]))
            {
                PrintFormat("APEX PositionTracker: early exit ticket=%I64u (composite reversed)",
                            m_contexts[i].ticket);
                m_trade_mgr.ClosePosition(m_contexts[i].ticket);
            }
        }
    }

    // True if the maximum number of positions is already open
    bool IsAtMaxPositions() const { return m_count >= InpMaxOpenPositions; }

    // Number of tracked open positions
    int GetOpenCount() const { return m_count; }

    // Returns context for a ticket (empty struct if not found)
    TradeContext GetContext(ulong ticket) const
    {
        int idx = find_idx(ticket);
        if(idx < 0) { TradeContext empty = {}; return empty; }
        return m_contexts[idx];
    }

    // Register a trade — public interface called by TradeManager
    void Add(const TradeContext &ctx) { RegisterTrade(ctx); }
};

//--- Now provide the deferred TradeManager::register_trade() implementation
void CTradeManager::register_trade(const TradeContext &ctx)
{
    ((CPositionTracker*)m_tracker).Add(ctx);
}
