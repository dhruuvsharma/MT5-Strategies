//+------------------------------------------------------------------+
//| RiskManager.mqh — APEX_SCALPER                                   |
//| Tracks daily P&L, drawdown, peak equity.                       |
//| Activates kill switch on limit breach.                         |
//| Provides dynamic lot sizing per the master spec formula.       |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Utils/MathUtils.mqh"

class CRiskManager
{
private:
    double   m_session_start_balance;  // balance at EA start (for drawdown base)
    datetime m_last_day;               // last calendar day for midnight reset
    double   m_point;

    // Current floating P&L across all EA positions
    double current_open_pnl() const
    {
        double pnl = 0.0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(PositionGetSymbol(i) == Symbol() &&
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                pnl += PositionGetDouble(POSITION_PROFIT);
        }
        return pnl;
    }

    // Reset daily tracking at midnight
    void check_midnight_reset()
    {
        datetime now = TimeCurrent();
        if(!IsSameDay(now, m_last_day))
        {
            m_last_day  = now;
            g_DailyPnL  = 0.0;
            // Do NOT reset peak equity — drawdown is from session high, not daily reset
        }
    }

    // Activate kill switch and publish event
    void activate_kill_switch(const string &reason)
    {
        if(g_KillSwitch) return;  // already active
        g_KillSwitch = true;
        PrintFormat("APEX RiskManager: KILL SWITCH activated — %s", reason);
        g_EventBus.Publish(EVENT_KILL_SWITCH_ACTIVATED);
    }

public:
    bool Initialize()
    {
        m_point                  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        m_session_start_balance  = AccountInfoDouble(ACCOUNT_BALANCE);
        m_last_day               = TimeCurrent();
        g_PeakEquity             = AccountInfoDouble(ACCOUNT_EQUITY);
        g_DailyPnL               = 0.0;
        g_KillSwitch             = false;
        return (m_point > 0.0);
    }

    // Call every tick to update risk state and check limits
    void OnTick()
    {
        check_midnight_reset();

        double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
        double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
        double open_pnl = current_open_pnl();

        // Update peak equity
        if(equity > g_PeakEquity) g_PeakEquity = equity;

        // Update daily realized P&L
        // Approximation: balance change since start of day reflects realized P&L
        // (accurate when no deposits/withdrawals occur intraday)
        static double day_start_balance = balance;
        if(TimeCurrent() - m_last_day < 2)    // just after midnight reset
            day_start_balance = balance;
        g_DailyPnL = balance - day_start_balance + open_pnl;

        // Kill switch: daily loss
        if(balance > 0.0)
        {
            double daily_loss_pct = -(g_DailyPnL / balance) * 100.0;
            if(daily_loss_pct >= InpMaxDailyLossPercent)
                activate_kill_switch(StringFormat("daily loss %.2f%% >= limit %.2f%%",
                                                   daily_loss_pct, InpMaxDailyLossPercent));
        }

        // Kill switch: drawdown from peak equity
        if(g_PeakEquity > 0.0)
        {
            double dd_pct = (g_PeakEquity - equity) / g_PeakEquity * 100.0;
            if(dd_pct >= InpMaxDrawdownPercent)
                activate_kill_switch(StringFormat("drawdown %.2f%% >= limit %.2f%%",
                                                   dd_pct, InpMaxDrawdownPercent));
        }
    }

    // Dynamic lot sizing per spec formula
    // sl_points: distance from entry to SL in points (not price)
    double CalculateLotSize(double sl_points) const
    {
        if(sl_points < 1e-10) return InpLotSize;

        double balance       = AccountInfoDouble(ACCOUNT_BALANCE);
        double tick_val      = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
        double tick_size     = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        if(tick_size < 1e-10 || tick_val < 1e-10) return InpLotSize;

        // tick_value_per_lot = tick_val / tick_size (value per 1-point move per lot)
        double val_per_point = tick_val / tick_size;
        if(val_per_point < 1e-10) return InpLotSize;

        double risk_amount = balance * InpRiskPercent / 100.0;
        double raw_lot     = risk_amount / (sl_points * val_per_point);

        // Clamp to broker limits and round to volume step
        double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
        if(step < 1e-10) step = 0.01;
        double lot = MathFloor(raw_lot / step) * step;
        lot = MathMax(lot, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN));
        lot = MathMin(lot, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX));
        return NormalizeDouble(lot, 2);
    }

    // Current drawdown % from peak equity
    double GetCurrentDrawdown() const
    {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        if(g_PeakEquity < 1e-10) return 0.0;
        return MathMax(0.0, (g_PeakEquity - equity) / g_PeakEquity * 100.0);
    }

    // Daily realized + floating P&L
    double GetDailyPnL() const { return g_DailyPnL; }

    // True if kill switch has been activated
    bool IsKillSwitchActive() const { return g_KillSwitch; }

    // Number of EA positions currently open (for max positions gate)
    int GetOpenPositionCount() const
    {
        int count = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
            if(PositionGetSymbol(i) == Symbol() &&
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                count++;
        return count;
    }
};
