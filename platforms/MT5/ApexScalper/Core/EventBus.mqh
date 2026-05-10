//+------------------------------------------------------------------+
//| EventBus.mqh — APEX_SCALPER                                      |
//| Simple in-process observer pattern pub/sub.                      |
//| No heap allocation. Uses fixed-size function pointer arrays.     |
//| Max APEX_MAX_EVENT_SUBSCRIBERS per event type.                  |
//+------------------------------------------------------------------+

#include "Defines.mqh"

//--- Callback typedef — all subscribers use this signature
typedef void (*ApexEventCallback)(ApexEvent event);

//+------------------------------------------------------------------+
//| CEventBus — static singleton-style event bus                    |
//+------------------------------------------------------------------+
class CEventBus
{
private:
    ApexEventCallback m_subscribers[EVENT_COUNT][APEX_MAX_EVENT_SUBSCRIBERS];
    int               m_sub_count[EVENT_COUNT];

public:
    // Initialize all subscriber arrays to NULL
    bool Initialize()
    {
        for(int e = 0; e < (int)EVENT_COUNT; e++)
        {
            m_sub_count[e] = 0;
            for(int s = 0; s < APEX_MAX_EVENT_SUBSCRIBERS; s++)
                m_subscribers[e][s] = NULL;
        }
        return true;
    }

    // Register a callback for an event; returns false if subscriber limit reached
    bool Subscribe(ApexEvent event, ApexEventCallback callback)
    {
        if(callback == NULL) return false;
        int idx = (int)event;
        if(idx < 0 || idx >= (int)EVENT_COUNT) return false;
        if(m_sub_count[idx] >= APEX_MAX_EVENT_SUBSCRIBERS) return false;
        m_subscribers[idx][m_sub_count[idx]++] = callback;
        return true;
    }

    // Fire all callbacks registered for an event
    void Publish(ApexEvent event)
    {
        int idx = (int)event;
        if(idx < 0 || idx >= (int)EVENT_COUNT) return;
        for(int s = 0; s < m_sub_count[idx]; s++)
        {
            if(m_subscribers[idx][s] != NULL)
                m_subscribers[idx][s](event);
        }
    }

    // Remove all subscribers for a specific event
    void ClearEvent(ApexEvent event)
    {
        int idx = (int)event;
        if(idx < 0 || idx >= (int)EVENT_COUNT) return;
        m_sub_count[idx] = 0;
        for(int s = 0; s < APEX_MAX_EVENT_SUBSCRIBERS; s++)
            m_subscribers[idx][s] = NULL;
    }

    // Remove all subscribers for all events
    void Reset() { Initialize(); }
};

//--- Global event bus instance (used by all modules via State.mqh include chain)
CEventBus g_EventBus;
