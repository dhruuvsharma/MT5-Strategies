# Memory: Render.mqh

## Purpose
Canvas rendering engine (CCanvas wrapper), drawing primitives, theme management with 16 color themes, intensity/imbalance color helpers.

## Exports (public functions)
- InitCanvas() → bool — creates CCanvas bitmap label
- DestroyCanvas() — destroys canvas
- ClearCanvas() — erases with background color
- FlushCanvas() — updates canvas to screen
- FillRect(x, y, w, h, clr, alpha)
- DrawRect(x, y, w, h, clr, alpha)
- DrawLine(x1, y1, x2, y2, clr, alpha)
- DrawText(x, y, text, font, fontSize, clr, flags)
- DrawTextCentered(x, y, text, font, fontSize, clr)
- DrawTextRight(x, y, text, font, fontSize, clr)
- GetTextWidth/GetTextHeight(text, font, fontSize) → int
- DrawTextWordWrap(x, y, maxWidth, text, font, fontSize, clr) → int (height used)
- FillCircle(cx, cy, radius, clr, alpha)
- DrawArc(cx, cy, radius, startAngle, endAngle, clr, thickness)
- DrawPointer(cx, cy, length, angleDeg, clr, thickness)
- DrawPanelFrame(x, y, w, h, title)
- ApplyColorTheme(theme) — sets all g_ color globals
- GetIntensityColor(buyVol, sellVol) → color — 6-level
- GetImbalanceBorderColor(level, isBuy) → color — 3-tier

## Dependencies
- Imports from: Config.mqh, <Canvas\Canvas.mqh>
- Imported by: Panels.mqh, FootprintChartPro.mq5

## Last Modified
- Date: 2026-04-14
- Change: Initial creation with full canvas engine, 16 themes, intensity colors.
