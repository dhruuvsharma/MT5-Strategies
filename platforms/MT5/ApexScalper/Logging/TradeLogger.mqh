//+------------------------------------------------------------------+
//| TradeLogger.mqh — APEX_SCALPER                                   |
//| Detects trade opens/closes via MT5 position/history scanning.  |
//| Writes one CSV row on open (partial) and one on close (full).  |
//| No changes required in TradeManager or PositionTracker.        |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Utils/StringUtils.mqh"
#include "../Utils/TimeUtils.mqh"
#include "SessionLogger.mqh"

//+------------------------------------------------------------------+
//| Internal struct — per-open-trade cache entry                    |
//+------------------------------------------------------------------+
struct TLEntry
{
    ulong    ticket;          // position ticket
    bool     logged_open;     // true once the open row has been written
    datetime entry_time;
    double   entry_price;
    double   sl;
    double   tp;
    double   lot;
    int      direction;       // +1 long / -1 short
    double   comp_score;      // composite score at entry tick
    int      signals_agree;
    bool     conflict_flag;
    string   regime;
    double   spread_at_entry;
    // Per-signal scores captured at entry
    double   s_delta, s_vpin, s_obi, s_fp;
    double   s_abs,   s_hvp,  s_tape, s_vpoc;
};

class CTradeLogger
{
private:
    TLEntry        m_cache[APEX_MAX_OPEN_POSITIONS];
    int            m_cache_count;
    datetime       m_last_history_time;  // last HistorySelect upper bound
    CSessionLogger *m_session;
    int            m_digits;

    //--- Build the dated file path for the trade log
    string file_path() const
    {
        string date = TimeToString(TimeCurrent(), TIME_DATE);
        StringReplace(date, ".", "-");
        return InpLogFolder + Symbol() + "_trades_" + date + ".csv";
    }

    //--- CSV header
    static string header()
    {
        return "Ticket,Symbol,Type,EntryTime,EntryPrice,SL,TP,"
               "CloseTime,ClosePrice,PnL,Lots,CompositeScore,Direction,SignalsAgree,"
               "Conflict,Regime,SpreadAtEntry,"
               "DeltaScore,VPINScore,OBIScore,FootprintScore,"
               "AbsorptionScore,HVPScore,TapeScore,VPOCScore\n";
    }

    //--- Append a row to the trade log file
    void append(const string &row) const
    {
        string path = file_path();
        bool   is_new = !FileIsExist(path);
        FolderCreate(InpLogFolder);
        int h = FileOpen(path, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
        if(h == INVALID_HANDLE) return;
        if(is_new) FileWriteString(h, header());
        FileSeek(h, 0, SEEK_END);
        FileWriteString(h, row);
        FileClose(h);
    }

    //--- Find a signal score in the CompositeResult by name prefix
    static double find_score(const CompositeResult &cr, const string prefix)
    {
        for(int i = 0; i < cr.component_count; i++)
            if(StringFind(cr.components[i].signal_name, prefix) == 0)
                return cr.components[i].score;
        return 0.0;
    }

    //--- Find cache entry index by ticket; returns -1 if not found
    int find_cache(ulong ticket) const
    {
        for(int i = 0; i < m_cache_count; i++)
            if(m_cache[i].ticket == ticket) return i;
        return -1;
    }

    //--- Capture current g_LastComposite into a new cache entry
    TLEntry build_entry(ulong ticket) const
    {
        TLEntry e;
        ZeroMemory(e);
        e.ticket         = ticket;
        e.logged_open    = false;

        // Populate from MT5 position
        if(PositionSelectByTicket(ticket))
        {
            e.entry_time   = (datetime)PositionGetInteger(POSITION_TIME);
            e.entry_price  = PositionGetDouble(POSITION_PRICE_OPEN);
            e.sl           = PositionGetDouble(POSITION_SL);
            e.tp           = PositionGetDouble(POSITION_TP);
            e.lot          = PositionGetDouble(POSITION_VOLUME);
            e.direction    = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
        }

        // Capture composite at the moment of detection (same tick as the trade open)
        CompositeResult cr = g_LastComposite;
        e.comp_score    = cr.score;
        e.signals_agree = cr.signals_agree;
        e.conflict_flag = cr.conflict_flag;
        e.regime        = RegimeToString(g_CurrentRegime);
        e.spread_at_entry = g_CurrentSpread;

        // Per-signal scores
        e.s_delta = find_score(cr, "DELTA");
        e.s_vpin  = find_score(cr, "VPIN");
        e.s_obi   = find_score(cr, "OBI");
        e.s_fp    = find_score(cr, "FOOTPRINT");
        e.s_abs   = find_score(cr, "ABSORPTION");
        e.s_hvp   = find_score(cr, "HVP");
        e.s_tape  = find_score(cr, "TAPE");
        e.s_vpoc  = find_score(cr, "VPOC");

        return e;
    }

    //--- Build and write the "open" CSV row for a cache entry
    void write_open_row(const TLEntry &e)
    {
        string type_str = (e.direction == 1) ? "BUY" : "SELL";
        string row = StringFormat(
            "%I64u,%s,%s,%s,%.*f,%.*f,%.*f,"
            ",,,"                   // CloseTime ClosePrice PnL (empty on open)
            "%.2f,"                 // Lots
            "%+.3f,%d,%d,"          // CompositeScore Direction SignalsAgree
            "%s,%s,%.2f,"           // Conflict Regime SpreadAtEntry
            "%+.3f,%+.3f,%+.3f,%+.3f,"   // Delta VPIN OBI Footprint
            "%+.3f,%+.3f,%+.3f,%+.3f\n", // Absorption HVP Tape VPOC
            e.ticket, Symbol(), type_str,
            DateTimeToCSV(e.entry_time),
            m_digits, e.entry_price,
            m_digits, e.sl,
            m_digits, e.tp,
            e.lot,
            e.comp_score, e.direction, e.signals_agree,
            e.conflict_flag ? "YES" : "NO",
            e.regime, e.spread_at_entry,
            e.s_delta, e.s_vpin, e.s_obi, e.s_fp,
            e.s_abs, e.s_hvp, e.s_tape, e.s_vpoc
        );
        append(row);
    }

    //--- Build and write the "close" CSV row
    void write_close_row(const TLEntry &e,
                         double close_price, double pnl, datetime close_time)
    {
        string type_str = (e.direction == 1) ? "BUY" : "SELL";
        string row = StringFormat(
            "%I64u,%s,%s,%s,%.*f,%.*f,%.*f,"
            "%s,%.*f,%.2f,"         // CloseTime ClosePrice PnL
            "%.2f,"                 // Lots
            "%+.3f,%d,%d,"          // CompositeScore Direction SignalsAgree
            "%s,%s,%.2f,"           // Conflict Regime SpreadAtEntry
            "%+.3f,%+.3f,%+.3f,%+.3f,"
            "%+.3f,%+.3f,%+.3f,%+.3f\n",
            e.ticket, Symbol(), type_str,
            DateTimeToCSV(e.entry_time),
            m_digits, e.entry_price,
            m_digits, e.sl,
            m_digits, e.tp,
            DateTimeToCSV(close_time),
            m_digits, close_price,
            pnl,
            e.lot,
            e.comp_score, e.direction, e.signals_agree,
            e.conflict_flag ? "YES" : "NO",
            e.regime, e.spread_at_entry,
            e.s_delta, e.s_vpin, e.s_obi, e.s_fp,
            e.s_abs, e.s_hvp, e.s_tape, e.s_vpoc
        );
        append(row);
    }

    //--- Remove a cache entry by index (shift array)
    void remove_cache(int idx)
    {
        for(int i = idx; i < m_cache_count - 1; i++)
            m_cache[i] = m_cache[i + 1];
        m_cache_count--;
    }

    //--- Scan open positions; detect new ones, log open rows
    void scan_opens()
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(PositionGetSymbol(i) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
            if(find_cache(ticket) >= 0) continue;  // already known

            // New position found — add to cache
            if(m_cache_count >= APEX_MAX_OPEN_POSITIONS) continue;
            m_cache[m_cache_count] = build_entry(ticket);
            write_open_row(m_cache[m_cache_count]);
            m_cache[m_cache_count].logged_open = true;
            if(m_session != NULL)
                m_session.OnTradeOpen(m_cache[m_cache_count].comp_score);
            m_cache_count++;
        }
    }

    //--- Scan deal history; detect new closes, log close rows
    void scan_closes()
    {
        // Look back 2 seconds before last check to avoid gaps
        datetime from = (m_last_history_time > 1) ? m_last_history_time - 2 : 0;
        datetime to   = TimeCurrent();
        m_last_history_time = to;

        if(!HistorySelect(from, to)) return;

        int total = HistoryDealsTotal();
        for(int i = 0; i < total; i++)
        {
            ulong deal = HistoryDealGetTicket(i);
            if(HistoryDealGetString(deal, DEAL_SYMBOL) != Symbol())                 continue;
            if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)     continue;
            if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

            // Match by position ID to our cache
            ulong pos_id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
            int   cidx   = find_cache(pos_id);
            if(cidx < 0) continue;  // not our tracked position

            double close_price = HistoryDealGetDouble(deal,   DEAL_PRICE);
            double pnl         = HistoryDealGetDouble(deal,   DEAL_PROFIT);
            datetime close_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
            bool   is_win      = (pnl > 0.0);

            write_close_row(m_cache[cidx], close_price, pnl, close_time);

            if(m_session != NULL)
                m_session.OnTradeClose(m_cache[cidx].comp_score, is_win);

            remove_cache(cidx);
        }
    }

public:
    bool Initialize()
    {
        if(!InpEnableTradeLog) { return true; }

        m_cache_count       = 0;
        m_last_history_time = TimeCurrent();
        m_session           = NULL;
        m_digits            = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
        FolderCreate(InpLogFolder);
        return true;
    }

    void SetSessionLogger(CSessionLogger *sl) { m_session = sl; }

    //--- Call every tick to detect opens and closes.
    void OnTick()
    {
        if(!InpEnableTradeLog) return;
        scan_opens();
        scan_closes();
    }

    //--- Returns current open-trade cache count (for diagnostics).
    int GetCacheCount() const { return m_cache_count; }
};
