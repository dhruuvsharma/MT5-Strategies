//+------------------------------------------------------------------+
//|                                                        Risk.mqh |
//|                                        DeltaFadeEA — Dhruv Sharma |
//+------------------------------------------------------------------+
#ifndef RISK_MQH
#define RISK_MQH

#include "Config.mqh"

//+------------------------------------------------------------------+
//| Calculate lot size — fixed or risk-based                         |
//+------------------------------------------------------------------+
double CalculatePositionSize()
{
    if(LotSize > 0) return LotSize;

    double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmt   = balance * RiskPercent / 100.0;
    double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double slPrice   = StopLossPoints * _Point;
    double pointVal  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    if(tickVal > 0 && slPrice > 0 && pointVal > 0)
    {
        double lots = riskAmt / (slPrice / pointVal * tickVal);
        return NormalizeDouble(lots, 2);
    }

    return 0.01;
}

//+------------------------------------------------------------------+
//| SL price for a BUY at the given entry                            |
//+------------------------------------------------------------------+
double CalculateBuySL(double entryPrice)
{
    return entryPrice - StopLossPoints * _Point;
}

//+------------------------------------------------------------------+
//| TP distance in points — fixed or from RR ratio                   |
//+------------------------------------------------------------------+
int GetTakeProfitPoints()
{
    if(TakeProfitPoints > 0) return TakeProfitPoints;
    return (int)MathRound(StopLossPoints * RiskRewardRatio);
}

//+------------------------------------------------------------------+
//| TP price for a BUY at the given entry                            |
//+------------------------------------------------------------------+
double CalculateBuyTP(double entryPrice)
{
    return entryPrice + GetTakeProfitPoints() * _Point;
}

//+------------------------------------------------------------------+
//| SL price for a SELL at the given entry                           |
//+------------------------------------------------------------------+
double CalculateSellSL(double entryPrice)
{
    return entryPrice + StopLossPoints * _Point;
}

//+------------------------------------------------------------------+
//| TP price for a SELL at the given entry                           |
//+------------------------------------------------------------------+
double CalculateSellTP(double entryPrice)
{
    return entryPrice - GetTakeProfitPoints() * _Point;
}

#endif
