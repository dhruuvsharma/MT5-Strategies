//+------------------------------------------------------------------+
//|                                                       Trade.mqh |
//|                                        DeltaFadeEA — Dhruv Sharma |
//+------------------------------------------------------------------+
#ifndef TRADE_MQH
#define TRADE_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "Config.mqh"
#include "Risk.mqh"
#include "Signal.mqh"

//--- CTrade instance
CTrade         trade;
CPositionInfo  posInfo;

//+------------------------------------------------------------------+
//| Initialise CTrade with magic and slippage                        |
//+------------------------------------------------------------------+
void TradeInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
}

//+------------------------------------------------------------------+
//| Open a BUY market order                                          |
//+------------------------------------------------------------------+
void EnterLong()
{
    double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double lots = CalculatePositionSize();
    double sl   = CalculateBuySL(ask);
    double tp   = CalculateBuyTP(ask);

    if(trade.Buy(lots, _Symbol, ask, sl, tp, EA_NAME " Long"))
    {
        Print("[", EA_NAME, "] BUY opened — ticket #", trade.ResultOrder());
        OnTradeExecuted();
    }
    else
    {
        Print("[", EA_NAME, "] BUY failed — error ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Open a SELL market order                                         |
//+------------------------------------------------------------------+
void EnterShort()
{
    double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lots = CalculatePositionSize();
    double sl   = CalculateSellSL(bid);
    double tp   = CalculateSellTP(bid);

    if(trade.Sell(lots, _Symbol, bid, sl, tp, EA_NAME " Short"))
    {
        Print("[", EA_NAME, "] SELL opened — ticket #", trade.ResultOrder());
        OnTradeExecuted();
    }
    else
    {
        Print("[", EA_NAME, "] SELL failed — error ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Trailing stop + position management loop                         |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!posInfo.SelectByIndex(i)) continue;
        if(posInfo.Symbol() != _Symbol)    continue;
        if(posInfo.Magic()  != MagicNumber) continue;

        ApplyTrailingStop(posInfo.Ticket());
    }
}

//+------------------------------------------------------------------+
//| Move SL towards profit if price has moved enough                 |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket)
{
    if(!posInfo.SelectByTicket(ticket)) return;

    double curSL    = posInfo.StopLoss();
    double curTP    = posInfo.TakeProfit();
    double curPrice = posInfo.PriceCurrent();
    double openPx   = posInfo.PriceOpen();

    if(posInfo.PositionType() == POSITION_TYPE_BUY)
    {
        double newSL = curPrice - TrailingStart * _Point;
        if(newSL > curSL && newSL > openPx)
        {
            if(!trade.PositionModify(ticket, newSL, curTP))
                Print("[", EA_NAME, "] Trailing SL modify failed — ticket ", ticket, " error ", GetLastError());
        }
    }
    else if(posInfo.PositionType() == POSITION_TYPE_SELL)
    {
        double newSL = curPrice + TrailingStart * _Point;
        if(newSL < curSL && newSL < openPx)
        {
            if(!trade.PositionModify(ticket, newSL, curTP))
                Print("[", EA_NAME, "] Trailing SL modify failed — ticket ", ticket, " error ", GetLastError());
        }
    }
}

//+------------------------------------------------------------------+
//| Check if a LONG position exists for this EA                      |
//+------------------------------------------------------------------+
bool HasLongPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!posInfo.SelectByIndex(i)) continue;
        if(posInfo.Symbol() == _Symbol &&
           posInfo.Magic()  == MagicNumber &&
           posInfo.PositionType() == POSITION_TYPE_BUY)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if a SHORT position exists for this EA                     |
//+------------------------------------------------------------------+
bool HasShortPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!posInfo.SelectByIndex(i)) continue;
        if(posInfo.Symbol() == _Symbol &&
           posInfo.Magic()  == MagicNumber &&
           posInfo.PositionType() == POSITION_TYPE_SELL)
            return true;
    }
    return false;
}

#endif
