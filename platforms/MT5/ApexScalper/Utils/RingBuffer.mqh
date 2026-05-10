//+------------------------------------------------------------------+
//| RingBuffer.mqh — APEX_SCALPER                                    |
//| Generic fixed-size ring buffer template.                         |
//| Pre-allocated at construction — zero dynamic allocation in use.  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| CRingBuffer<T> — fixed-capacity FIFO with newest-first access   |
//+------------------------------------------------------------------+
template<typename T>
class CRingBuffer
{
private:
    T     m_data[];       // fixed-size backing array
    int   m_capacity;     // maximum number of elements
    int   m_size;         // current number of elements stored
    int   m_head;         // index of the newest element

public:
    // Allocate backing array; returns false if capacity <= 0
    bool Initialize(int capacity)
    {
        if(capacity <= 0) return false;
        m_capacity = capacity;
        m_size     = 0;
        m_head     = 0;
        ArrayResize(m_data, m_capacity);
        return true;
    }

    // Add a new value; oldest element is overwritten when full
    void Push(const T &value)
    {
        if(m_capacity <= 0) return;
        m_head = (m_head + 1) % m_capacity;
        m_data[m_head] = value;
        if(m_size < m_capacity) m_size++;
    }

    // Populate out with element at logical index (0 = newest, Size()-1 = oldest)
    void Get(int index, T &out) const
    {
        if(index < 0 || index >= m_size) { ZeroMemory(out); return; }
        int physical = (m_head - index + m_capacity) % m_capacity;
        out = m_data[physical];
    }

    // Fill out[] with all elements newest-first; returns element count written
    int ToArray(T &out[]) const
    {
        ArrayResize(out, m_size);
        for(int i = 0; i < m_size; i++)
            Get(i, out[i]);
        return m_size;
    }

    // Return number of elements currently stored
    int Size() const { return m_size; }

    // Return maximum capacity
    int Capacity() const { return m_capacity; }

    // Return true if the buffer has reached its capacity
    bool IsFull() const { return m_size == m_capacity; }

    // Clear all elements (does not free memory)
    void Reset()
    {
        m_size = 0;
        m_head = 0;
    }
};

//--- Explicit instantiations used by this project (MQL5 template limitation workaround)
//    Additional types can be added here as needed by new modules.
// CRingBuffer<double>  — used by MathUtils rolling stats
// CRingBuffer<long>    — used by tape speed / tick counters
// CRingBuffer<ApexTick> — used by TickCollector (included via Defines.mqh)
