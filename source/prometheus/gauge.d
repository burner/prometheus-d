module prometheus.gauge;

import prometheus.metric;
import prometheus.encoding;

import std.exception : enforce;
import std.format : format;
import std.range : empty;

@safe:

class Gauge : Metric
{
@safe:
    private double[string[]] values;

    this(string name, string help, string[] labels)
    {
        this.name = name;
        this.help = help;
        this.labels = labels.dup;

        //if there are no labels, then the value defaults to zero.
        if(labels is null || labels.length == 0)
            this.values[(string[]).init.idup] = 0;
    }

    override void observe(double value, string[] labelValues)
    {
        enforce(this.labels.length == labelValues.length);

        if(labelValues in this.values)
            this.values[labelValues.idup] += value;
        else
            this.values[labelValues.idup] = value;
    }

    void inc(double value = 1, string[] labelValues = [])
    {
        this.observe(value, labelValues);
    }

    void dec(double value = 1, string[] labelValues = [])
    {
        this.observe(-value, labelValues);
    }

    void set(double value, string[] labelValues = [])
    {
        enforce(this.labels.length == labelValues.length);

        this.values[labelValues.idup] = value;
    }

    void setToCurrentTime(string[] labelValues = [])
    {
        this.set(Metric.posixTime / 1000.0, labelValues);
    }

    override MetricSnapshot collect()
    {
        return new GaugeSnapshot(this);
    }
}

unittest
{
    auto g = new Gauge("test", "testing", null);
    assert(g.values[(string[]).init.idup] == 0);

    g.inc;
    assert(g.values[(string[]).init.idup] == 1);

    g.set(35);
    assert(g.values[(string[]).init.idup] == 35);

    g.observe(2, null);
    assert(g.values[(string[]).init.idup] == 37);

    g.set(0);
    assert(g.values[(string[]).init.idup] == 0);
}

private class GaugeSnapshot : MetricSnapshot
{
@safe:
    string name;
    string help;
    string[] labels;
    double[string[]] values;
    long timestamp;

    this(Gauge g)
    {
        this.name = g.name;
        this.help = g.help;
        this.labels = g.labels;
        foreach(k,v; g.values)
            this.values[k.idup] = v;

        this.timestamp = Metric.posixTime;
    }

    override string encode(EncodingFormat fmt = EncodingFormat.text)
    {
        enforce(fmt == EncodingFormat.text, "Unsupported encoding type");

        string output = "";

        if(!this.help.empty) {
            output ~= TextEncoding.encodeHelp(this.name, this.help);
		}

        output ~= TextEncoding.encodeType(this.name, "gauge");

        foreach(labelValues, value; this.values) {
            output ~= TextEncoding.encodeMetricLine(
                this.name,
                this.labels,
                labelValues,
                value,
                this.timestamp);
		}

        return output;
    }
}
