//+------------------------------------------------------------------+
//| ConfirmationGate.mqh — APEX_SCALPER                              |
//| Final pre-trade gate. Checks composite score, regime, session,  |
//| spread, news, risk cooldown, and position count.               |
//| Includes Risk layer headers directly (integration point).       |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Risk/SessionFilter.mqh"
#include "../Risk/SpreadFilter.mqh"
#include "../Risk/NewsFilter.mqh"
#include "../Risk/RiskManager.mqh"

//+------------------------------------------------------------------+
//| CConfirmationGate                                                |
//+------------------------------------------------------------------+
class CConfirmationGate
{
private:
    CSessionFilter *m_session;
    CSpreadFilter  *m_spread;
    CNewsFilter    *m_news;
    CRiskManager   *m_risk;
    string          m_last_reject_reason;

public:
    bool Initialize()
    {
        m_session            = NULL;
        m_spread             = NULL;
        m_news               = NULL;
        m_risk               = NULL;
        m_last_reject_reason = "";
        return true;
    }

    // Inject Session 9 module pointers after they are instantiated
    void SetSessionFilter(CSessionFilter *sf) { m_session = sf; }
    void SetSpreadFilter(CSpreadFilter   *sf) { m_spread  = sf; }
    void SetNewsFilter(CNewsFilter       *nf) { m_news    = nf; }
    void SetRiskManager(CRiskManager     *rm) { m_risk    = rm; }

    // Core gate check — returns true and sets direction_out if all conditions pass
    bool ShouldTrade(int &direction_out)
    {
        direction_out = 0;
        CompositeResult cr = g_LastComposite;

        // 1. Kill switch
        if(g_KillSwitch)
        { m_last_reject_reason = "KILL_SWITCH"; return false; }

        // 2. Composite must allow trade (set by ConflictFilter)
        if(!cr.trade_allowed)
        { m_last_reject_reason = "CONFLICT/AGREE"; return false; }

        // 3. Score threshold
        if(MathAbs(cr.score) < InpCompositeThreshold)
        { m_last_reject_reason = StringFormat("SCORE_LOW %.2f", cr.score); return false; }

        // 4. Minimum signal agreement
        if(cr.signals_agree < InpMinSignalsAgree)
        { m_last_reject_reason = StringFormat("AGREE %d<%d", cr.signals_agree, InpMinSignalsAgree); return false; }

        // 5. High volatility regime block
        if(g_CurrentRegime == REGIME_HIGH_VOLATILITY)
        { m_last_reject_reason = "HIGH_VOL_REGIME"; return false; }

        // 6. Session filter
        if(m_session != NULL && !m_session.IsAllowed())
        { m_last_reject_reason = "SESSION_BLOCKED"; return false; }

        // 7. Spread filter
        if(m_spread != NULL && !m_spread.IsOK())
        { m_last_reject_reason = StringFormat("SPREAD %.1f>%.1f",
              g_CurrentSpread, InpMaxSpreadPoints); return false; }
        else if(m_spread == NULL && g_CurrentSpread > InpMaxSpreadPoints && InpMaxSpreadPoints > 0)
        { m_last_reject_reason = "SPREAD_TOO_WIDE"; return false; }

        // 8. News blackout
        if(m_news != NULL && !m_news.IsAllowed())
        { m_last_reject_reason = "NEWS_BLACKOUT"; return false; }
        else if(m_news == NULL && g_NewsBlackout)
        { m_last_reject_reason = "NEWS_BLACKOUT"; return false; }

        // 9. Risk cooldown: bars since last trade
        if(g_BarsSinceLastTrade < InpMinBarsBetweenTrades)
        { m_last_reject_reason = StringFormat("COOLDOWN %d/%d",
              g_BarsSinceLastTrade, InpMinBarsBetweenTrades); return false; }

        // 10. Maximum open positions
        if(m_risk != NULL)
        {
            if(m_risk.GetOpenPositionCount() >= InpMaxOpenPositions)
            { m_last_reject_reason = "MAX_POSITIONS"; return false; }
        }
        else
        {
            int open = 0;
            for(int i = PositionsTotal() - 1; i >= 0; i--)
                if(PositionGetSymbol(i) == Symbol() &&
                   PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                    open++;
            if(open >= InpMaxOpenPositions)
            { m_last_reject_reason = "MAX_POSITIONS"; return false; }
        }

        direction_out        = cr.direction;
        m_last_reject_reason = "";
        return (direction_out != 0);
    }

    // Human-readable reason for last rejection (empty if last check passed)
    string GetLastRejectReason() const { return m_last_reject_reason; }
};
