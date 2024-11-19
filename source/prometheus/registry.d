module prometheus.registry;

import std.array : array;
import std.concurrency : initOnce;

import prometheus.metric;

@safe:

class Registry
{
@safe:
    private __gshared Registry instance;

    static Registry global() @system
    {
        return initOnce!instance(new Registry);
    }

    private Metric[Metric] _metrics;

    this()
    {
    }

    void register(Metric m)
    {
        synchronized (this)
        {
            this._metrics[m] = m;
        }
    }

    void unregister(Metric m)
    {
        synchronized (this)
        {
            this._metrics.remove(m);
        }
    }

    @property Metric[] metrics()
    {

        return this._metrics.byValue.array;
    }
}

@system unittest
{
    // given
    alias UnderTest = Registry;

    // when
    auto registry = UnderTest.global;

    // then
	assert(registry !is null);
}

@system unittest
{
    // given
    alias UnderTest = Registry;
    auto registry1 = UnderTest.global;

    // when
    auto registry2 = UnderTest.global;

    // then
	assert(registry1 is registry2);
}
