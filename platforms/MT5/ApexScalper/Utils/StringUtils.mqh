//+------------------------------------------------------------------+
//| StringUtils.mqh — APEX_SCALPER                                   |
//| Formatting helpers for panel display and CSV log output.        |
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| FormatScore — formats a signal score to 2 dp with sign         |
//+------------------------------------------------------------------+
string FormatScore(double score)
{
    return StringFormat("%+.2f", score);
}

//+------------------------------------------------------------------+
//| FormatConfidence — formats confidence as percentage string      |
//+------------------------------------------------------------------+
string FormatConfidence(double conf)
{
    return StringFormat("%.0f%%", conf * 100.0);
}

//+------------------------------------------------------------------+
//| FormatPrice — formats a price with the symbol's digit count     |
//+------------------------------------------------------------------+
string FormatPrice(double price, int digits)
{
    return DoubleToString(price, digits);
}

//+------------------------------------------------------------------+
//| FormatLot — lot size with 2 decimal places                      |
//+------------------------------------------------------------------+
string FormatLot(double lot)
{
    return StringFormat("%.2f", lot);
}

//+------------------------------------------------------------------+
//| FormatPnL — P&L with sign and 2 dp, in account currency        |
//+------------------------------------------------------------------+
string FormatPnL(double pnl)
{
    return StringFormat("%+.2f", pnl);
}

//+------------------------------------------------------------------+
//| FormatSpread — spread in points with 1 dp                       |
//+------------------------------------------------------------------+
string FormatSpread(double spread_points)
{
    return StringFormat("%.1f pts", spread_points);
}

//+------------------------------------------------------------------+
//| FormatAgeSeconds — converts an age in ms to "Xs" or "Xm Ys"   |
//+------------------------------------------------------------------+
string FormatAgeSeconds(int age_ms)
{
    int total_sec = age_ms / 1000;
    if(total_sec < 60) return StringFormat("%ds", total_sec);
    return StringFormat("%dm%ds", total_sec / 60, total_sec % 60);
}

//+------------------------------------------------------------------+
//| FormatDrawdown — drawdown percentage string                     |
//+------------------------------------------------------------------+
string FormatDrawdown(double pct)
{
    return StringFormat("%.2f%%", pct);
}

//+------------------------------------------------------------------+
//| SignalStatusString — LIVE / STALE / NO DATA for dashboard LED   |
//+------------------------------------------------------------------+
string SignalStatusString(bool is_valid, int age_ms, int ttl_ms)
{
    if(!is_valid)         return "NO DATA";
    if(age_ms > ttl_ms)   return "STALE";
    return "LIVE";
}

//+------------------------------------------------------------------+
//| ScoreBar — builds a fixed-width ASCII bar for terminal logging  |
//| width = total characters; score clamped to [-3, +3]            |
//+------------------------------------------------------------------+
string ScoreBar(double score, int width)
{
    int half   = width / 2;
    double pct = MathAbs(score) / 3.0;
    int fill   = (int)MathRound(pct * half);
    string bar = "";
    if(score >= 0)
    {
        for(int i = 0; i < half;        i++) bar += " ";
        for(int i = 0; i < fill;        i++) bar += "+";
        for(int i = fill; i < half;     i++) bar += " ";
    }
    else
    {
        for(int i = half - fill; i < half; i++) bar = " " + bar; // right-align negative fill
        for(int i = 0; i < fill;            i++) bar = "-" + bar;
        for(int i = (int)StringLen(bar); i < width; i++) bar += " ";
    }
    return "|" + bar + "|";
}

//+------------------------------------------------------------------+
//| CSVEscape — wraps a field in quotes if it contains commas       |
//+------------------------------------------------------------------+
string CSVEscape(const string &field)
{
    if(StringFind(field, ",") >= 0 || StringFind(field, "\"") >= 0)
        return "\"" + field + "\"";
    return field;
}

//+------------------------------------------------------------------+
//| CSVRow — joins fields into a comma-separated row string         |
//+------------------------------------------------------------------+
string CSVRow(const string &fields[], int count)
{
    string row = "";
    for(int i = 0; i < count; i++)
    {
        if(i > 0) row += ",";
        row += CSVEscape(fields[i]);
    }
    return row + "\n";
}

//+------------------------------------------------------------------+
//| DateTimeToCSV — datetime as "YYYY.MM.DD HH:MM:SS"              |
//+------------------------------------------------------------------+
string DateTimeToCSV(datetime t)
{
    MqlDateTime dt;
    TimeToStruct(t, dt);
    return StringFormat("%04d.%02d.%02d %02d:%02d:%02d",
                        dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
//| PadRight — right-pad a string to a fixed width with spaces     |
//+------------------------------------------------------------------+
string PadRight(const string &s, int width)
{
    string out = s;
    while((int)StringLen(out) < width) out += " ";
    return out;
}

//+------------------------------------------------------------------+
//| PadLeft — left-pad a string to a fixed width with spaces       |
//+------------------------------------------------------------------+
string PadLeft(const string &s, int width)
{
    string out = s;
    while((int)StringLen(out) < width) out = " " + out;
    return out;
}

//+------------------------------------------------------------------+
//| UNIT TEST — call from OnInit in debug builds                    |
//+------------------------------------------------------------------+
bool StringUtils_RunTests()
{
    bool ok = true;

    if(FormatScore(2.5)  != "+2.50")  { Print("FAIL FormatScore pos: ", FormatScore(2.5));  ok = false; }
    if(FormatScore(-1.0) != "-1.00")  { Print("FAIL FormatScore neg: ", FormatScore(-1.0)); ok = false; }
    if(FormatScore(0.0)  != "+0.00")  { Print("FAIL FormatScore zero: ", FormatScore(0.0)); ok = false; }

    if(FormatAgeSeconds(500)   != "0s")    { Print("FAIL Age 500ms: ",   FormatAgeSeconds(500));   ok = false; }
    if(FormatAgeSeconds(5000)  != "5s")    { Print("FAIL Age 5s: ",    FormatAgeSeconds(5000));  ok = false; }
    if(FormatAgeSeconds(90000) != "1m30s") { Print("FAIL Age 90s: ",   FormatAgeSeconds(90000)); ok = false; }

    string fields[] = {"EURUSD", "1.08500", "BUY"};
    string row = CSVRow(fields, 3);
    if(StringFind(row, "EURUSD,1.08500,BUY") < 0) { Print("FAIL CSVRow: ", row); ok = false; }

    string padded = PadRight("AB", 5);
    if(padded != "AB   ") { Print("FAIL PadRight: '", padded, "'"); ok = false; }

    if(ok) Print("StringUtils: all tests PASSED");
    return ok;
}
