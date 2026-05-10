//+------------------------------------------------------------------+
//| PanelTheme.mqh — APEX_SCALPER                                    |
//| Layout constants, font sizes, and color helpers for the UI.    |
//| All pixel sizes are absolute. Color values read from Inputs.mqh.|
//+------------------------------------------------------------------+

#include "../Core/Defines.mqh"
#include "../Core/Inputs.mqh"

//--- Layout constants (pixels)
#define APEX_PNL_HDR_H      22   // height of the main header bar
#define APEX_PNL_ROW_H      17   // height of each data row
#define APEX_PNL_SEC_H      15   // height of a section sub-header
#define APEX_PNL_SEC_GAP     3   // vertical gap before each section
#define APEX_PNL_PAD_X       6   // horizontal padding inside panel
#define APEX_PNL_BAR_W      58   // total width of a score bar (±3 → 29px each side)
#define APEX_PNL_BAR_H      11   // height of the score bar fill region

//--- Column X offsets within a signal row (relative to panel left)
#define APEX_PNL_COL_LED     6   // LED indicator dot
#define APEX_PNL_COL_NAME   17   // signal name text
#define APEX_PNL_COL_BAR   108   // start of score bar
#define APEX_PNL_COL_SCORE 172   // numeric score
#define APEX_PNL_COL_STAT  212   // LIVE/STALE status

//--- Font definitions
#define APEX_PNL_FONT       "Consolas"
#define APEX_PNL_FONT_SM     7   // tiny: column headers, debug notes
#define APEX_PNL_FONT_MD     8   // standard: labels, values
#define APEX_PNL_FONT_LG    10   // medium: section labels, regime badge
#define APEX_PNL_FONT_XL    12   // large: composite score number

//--- Extra theme colors (not from inputs — fixed dark-theme values)
#define APEX_PNL_COLOR_DARK     C'8,8,12'      // score bar empty region
#define APEX_PNL_COLOR_ROW_ALT  C'20,20,28'    // alternate row tint
#define APEX_PNL_COLOR_SEC_BG   C'18,18,28'    // section sub-header background
#define APEX_PNL_COLOR_HDR_BG   C'28,28,45'    // main header background
#define APEX_PNL_COLOR_STALE    C'75,75,95'    // stale data / greyed text
#define APEX_PNL_COLOR_WARNING  C'220,180,0'   // conflict / warning yellow
#define APEX_PNL_COLOR_CTR_LINE C'50,50,70'    // score bar center divider

//+------------------------------------------------------------------+
//| Return score color based on direction.                           |
//+------------------------------------------------------------------+
color ApexScoreColor(int direction)
{
    if(direction > 0) return InpBullColor;
    if(direction < 0) return InpBearColor;
    return InpNeutralColor;
}

//+------------------------------------------------------------------+
//| Return fill width in pixels for a score bar given |score|.      |
//| Maps 0→3 to 0→half-bar-width.                                   |
//+------------------------------------------------------------------+
int ApexBarFillWidth(double score)
{
    double abs_s = MathMin(MathAbs(score), APEX_SCORE_MAX);
    return (int)MathRound(abs_s / APEX_SCORE_MAX * (APEX_PNL_BAR_W / 2));
}
