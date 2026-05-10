//+------------------------------------------------------------------+
//| SessionLogger.mqh — APEX_SCALPER                                 |
//| Writes a single-row session summary to CSV on EA stop.         |
//| Tracks: max drawdown, avg composite on entry, win/loss scores. |
//| Called from TradeLogger on trade events; OnTick for drawdown.  |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Utils/StringUtils.mqh"
#include "../Utils/TimeUtils.mqh"

class CSessionLogger
{
private:
    datetime m_session_start;
    double   m_start_balance;
    double   m_max_drawdown;       // peak drawdown % seen since start
    double   m_sum_entry_score;    // composite score sum at trade entries
    int      m_count_entry;
    double   m_sum_win_score;
    int      m_count_win;
    double   m_sum_loss_score;
    int      m_count_loss;
    int      m_regime_count[5];    // count of each ApexRegime value seen per tick
    long     m_tick_count;

    //--- Build the dated file path for the session log
    string file_path() const
    {
        string date = TimeToString(m_session_start, TIME_DATE);
        StringReplace(date, ".", "-");
        return InpLogFolder + Symbol() + "_sessions_" + date + ".csv";
    }

    //--- CSV header row
    static string header()
    {
        return "Date,Symbol,TF,TotalTrades,WinRate,TotalPnL,MaxDrawdown,"
               "AvgCompositeOnEntry,AvgWinScore,AvgLossScore,DominantRegime\n";
    }

    //--- Return the most frequently seen regime string
    string dominant_regime() const
    {
        int best_idx = 0;
        for(int i = 1; i < 5; i++)
            if(m_regime_count[i] > m_regime_count[best_idx]) best_idx = i;
        return RegimeToString((ApexRegime)best_idx);
    }

    //--- Write a string to file in append mode; create with header if new.
    void append(const string path, const string row) const
    {
        bool is_new = !FileIsExist(path);
        FolderCreate(InpLogFolder);
        int h = FileOpen(path, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
        if(h == INVALID_HANDLE) return;
        if(is_new) FileWriteString(h, header());
        FileSeek(h, 0, SEEK_END);
        FileWriteString(h, row);
        FileClose(h);
    }

public:
    bool Initialize()
    {
        m_session_start  = TimeCurrent();
        m_start_balance  = AccountInfoDouble(ACCOUNT_BALANCE);
        m_max_drawdown   = 0.0;
        m_sum_entry_score = 0.0; m_count_entry  = 0;
        m_sum_win_score   = 0.0; m_count_win    = 0;
        m_sum_loss_score  = 0.0; m_count_loss   = 0;
        m_tick_count     = 0;
        ArrayInitialize(m_regime_count, 0);
        return true;
    }

    //--- Call every tick to update drawdown and regime histogram.
    void OnTick()
    {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        if(g_PeakEquity > 1e-10)
        {
            double dd = (g_PeakEquity - equity) / g_PeakEquity * 100.0;
            if(dd > m_max_drawdown) m_max_drawdown = dd;
        }

        int ri = (int)g_CurrentRegime;
        if(ri >= 0 && ri < 5) m_regime_count[ri]++;
        m_tick_count++;
    }

    //--- Call when a new trade opens (from TradeLogger).
    void OnTradeOpen(double composite_score)
    {
        m_sum_entry_score += composite_score;
        m_count_entry++;
    }

    //--- Call when a trade closes (from TradeLogger).
    void OnTradeClose(double entry_composite_score, bool is_win)
    {
        if(is_win) { m_sum_win_score  += entry_composite_score; m_count_win++;  }
        else        { m_sum_loss_score += entry_composite_score; m_count_loss++; }
    }

    //--- Write the session summary row. Call from OnDeinit.
    void WriteSessionSummary()
    {
        if(!InpEnableSessionLog) return;

        double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
        double total_pnl   = balance - m_start_balance;
        double win_rate    = (g_TotalTrades > 0)
                             ? (double)g_WinningTrades / (double)g_TotalTrades * 100.0 : 0.0;
        double avg_entry   = (m_count_entry > 0) ? m_sum_entry_score / m_count_entry : 0.0;
        double avg_win     = (m_count_win   > 0) ? m_sum_win_score   / m_count_win   : 0.0;
        double avg_loss    = (m_count_loss  > 0) ? m_sum_loss_score  / m_count_loss  : 0.0;

        string date  = TimeToString(m_session_start, TIME_DATE);
        StringReplace(date, ".", "-");

        string row = StringFormat(
            "%s,%s,%s,%d,%.1f,%.2f,%.2f%%,%.3f,%.3f,%.3f,%s\n",
            date,
            Symbol(),
            EnumToString(InpTimeframe),
            g_TotalTrades,
            win_rate,
            total_pnl,
            m_max_drawdown,
            avg_entry,
            avg_win,
            avg_loss,
            dominant_regime()
        );

        append(file_path(), row);
        PrintFormat("APEX SessionLogger: session summary written — %d trades, win %.1f%%, P&L %.2f",
                    g_TotalTrades, win_rate, total_pnl);
    }
};
