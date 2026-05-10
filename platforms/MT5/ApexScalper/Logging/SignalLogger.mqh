//+------------------------------------------------------------------+
//| SignalLogger.mqh — APEX_SCALPER                                  |
//| Per-tick signal log (HIGH I/O — only when InpEnableSignalLog). |
//| File handle stays open across ticks for efficiency.            |
//| Format: Timestamp, composite fields, per-signal score+conf,    |
//|         regime, spread.                                         |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"
#include "../Core/State.mqh"
#include "../Utils/StringUtils.mqh"
#include "../Utils/TimeUtils.mqh"

class CSignalLogger
{
private:
    int  m_handle;         // file handle — kept open between ticks
    bool m_active;         // true if logging is enabled and file is open
    bool m_header_written; // true once CSV header has been flushed

    //--- Build dated file path
    string file_path() const
    {
        string date = TimeToString(TimeCurrent(), TIME_DATE);
        StringReplace(date, ".", "-");
        return InpLogFolder + Symbol() + "_signals_" + date + ".csv";
    }

    //--- CSV header: one column per signal (score + confidence)
    string build_header(const CompositeResult &cr) const
    {
        string h = "Timestamp,CompositeScore,CompositeDir,SignalsAgree,TradeAllowed,Conflict";
        for(int i = 0; i < cr.component_count; i++)
            h += "," + cr.components[i].signal_name + "_Score"
               + "," + cr.components[i].signal_name + "_Conf"
               + "," + cr.components[i].signal_name + "_Valid";
        h += ",Regime,Spread\n";
        return h;
    }

public:
    bool Initialize()
    {
        m_handle        = INVALID_HANDLE;
        m_active        = false;
        m_header_written = false;

        if(!InpEnableSignalLog) return true;

        FolderCreate(InpLogFolder);

        string path   = file_path();
        bool   is_new = !FileIsExist(path);

        m_handle = FileOpen(path, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
        if(m_handle == INVALID_HANDLE)
        {
            PrintFormat("APEX SignalLogger: cannot open %s", path);
            return true;  // non-fatal — main EA continues
        }

        // Write header only for new files — use g_LastComposite if available,
        // otherwise defer header to first OnTick when component names are known
        if(is_new && g_LastComposite.component_count > 0)
        {
            FileWriteString(m_handle, build_header(g_LastComposite));
            m_header_written = true;
        }

        FileSeek(m_handle, 0, SEEK_END);
        m_active = true;
        return true;
    }

    //--- Call every tick. Writes one CSV row from g_LastComposite.
    void OnTick()
    {
        if(!m_active || m_handle == INVALID_HANDLE) return;

        CompositeResult cr = g_LastComposite;

        // Lazy-write header if it was deferred (component_count wasn't known at Initialize)
        if(!m_header_written && cr.component_count > 0)
        {
            FileWriteString(m_handle, build_header(cr));
            m_header_written = true;
        }

        // Build row
        string row = StringFormat("%s,%+.4f,%d,%d,%s,%s",
            DateTimeToCSV(cr.timestamp),
            cr.score,
            cr.direction,
            cr.signals_agree,
            cr.trade_allowed ? "1" : "0",
            cr.conflict_flag ? "1" : "0"
        );

        for(int i = 0; i < cr.component_count; i++)
        {
            row += StringFormat(",%+.4f,%.3f,%s",
                cr.components[i].score,
                cr.components[i].confidence,
                cr.components[i].is_valid ? "1" : "0"
            );
        }

        row += "," + RegimeToString(g_CurrentRegime);
        row += StringFormat(",%.2f\n", g_CurrentSpread);

        FileWriteString(m_handle, row);
        // Note: no FileFlush() on every tick — let OS buffer for performance.
        // Flush on Deinitialize() is sufficient.
    }

    //--- Flush and close the log file.
    void Deinitialize()
    {
        if(m_handle != INVALID_HANDLE)
        {
            FileFlush(m_handle);
            FileClose(m_handle);
            m_handle = INVALID_HANDLE;
        }
        m_active = false;
    }
};
