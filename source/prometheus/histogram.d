/*
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/.
 */

module prometheus.histogram;

import std.algorithm.comparison : equal;
import std.conv : to;
import std.exception : enforce;
import std.math : pow;
import std.range : empty;

import prometheus.metric;
import prometheus.encoding;

@safe:

class Histogram : Metric
{
@safe:
    private double[] bucketValues;
    private HistogramBucket[string[]] buckets;

    this(string name, string help, string[] labels, double[] buckets)
    {
        this.name = name;
        this.help = help;
        this.labels = labels.dup;
        this.bucketValues = buckets.dup;

        if(labels is null || labels.length == 0)
            this.buckets[(string[]).init.idup] = HistogramBucket(this);
    }

    override void observe(double value, string[] labelValues = null)
    {
        enforce(labelValues.length == this.labels.length);

        auto indexValue = labelValues.idup;

        if(!(labelValues in this.buckets))
            this.buckets[indexValue] = HistogramBucket(this);

        this.buckets[indexValue].observe(value);
    }

    override MetricSnapshot collect()
    {
        return new HistogramSnapshot(this);
    }
}

//test lifecycle w/ no labels
unittest
{
    auto h = new Histogram("test", "testing description", null, Buckets.linear(0, 1, 5));

	// should not throw
    h.observe(-1);
    h.observe( 0);
    h.observe( 1);
    h.observe( 2);
    h.observe( 3);
    h.observe( 4);
    h.observe( 5);
    h.observe( 6);

    h.collect.encode();
}

//test lifecycle w/ labels
unittest
{
    auto h = new Histogram("test", "test w/ labels", ["verb"], Buckets.linear(0, 1, 2));

    foreach(verb; ["get", "set"]) {
        for(int i = -1; i < 5; i++) {
            h.observe(i, [verb]);
		}
	}

    h.collect.encode();
}

struct HistogramBucket
{
@safe:
    private Histogram parent;
    private double[] values;
    private double sum;

    this(Histogram parent)
    {
        this.sum = 0;
        this.parent = parent;
        this.values = new double[this.parent.bucketValues.length + 1];
        for(int i = 0; i < this.values.length; i++) {
            this.values[i] = 0;
		}
    }

    void observe(double value)
    {
        this.sum += value;

        this.values[this.values.length-1]++; // inf bucket

        for(long i = this.values.length - 2; i > -1; i--) {
            if(value > this.parent.bucketValues[i]) {
                break;
			}

            this.values[i]++;
        }
    }

    HistogramBucket dup()
    {
        auto ret = HistogramBucket(this.parent);
        ret.sum = this.sum;
        ret.values = this.values.dup;
        return ret;
    }
}

final class Buckets
{
@safe:
    static double[] linear(double start, double width, long count)
    {
        double[] ret = new double[count-1];
        for(int i = 0; i < count - 1; i++)
        {
            ret[i] = start + (width * i);
        }
        return ret;
    }

    static double[] exponential(double start, double factor, long count)
    {
        double[] ret = new double[count-1];
        for(int i = 0; i < count - 1; i++)
        {
            ret[i] = start * pow(factor, i);
        }
        return ret;
    }
}

//test linear
unittest
{
	{
		auto lin1 = Buckets.linear(0, 1, 4);
		assert(lin1.length == 3, to!(string)(lin1.length));
		assert(equal(lin1[], [0, 1, 2]));
	}

	{
		auto lin2 = Buckets.linear(-1, 1, 5);
		assert(lin2.length == 4, to!(string)(lin2.length));
		assert(equal(lin2[], [-1, 0, 1, 2]));
	}
}

//test exponential

private class HistogramSnapshot : MetricSnapshot
{
@safe:
    string name;
    string help;
    string[] labels;
    double[] bucketValues;
    HistogramBucket[string[]] buckets;
    long timestamp;

    this(Histogram h)
    {
        this.name = h.name;
        this.help = h.help;
        this.labels = h.labels;
        this.bucketValues = h.bucketValues;

        foreach(k, v; h.buckets)
            this.buckets[k] = v.dup;

        this.timestamp = Metric.posixTime;
    }

    override string encode(EncodingFormat fmt = EncodingFormat.text)
    {
        string output = "";

        if(!this.help.empty) {
            output ~= TextEncoding.encodeHelp(this.name, this.help);
		}

        output ~= TextEncoding.encodeType(this.name, "counter");

        foreach(labelValues, value; this.buckets) {
            this.writeBucket(output, labelValues, value);
		}

        return output;
    }

    private void writeBucket(ref string output, const ref string[] labelValues, const ref HistogramBucket bucket)
    {
        for(int i = 0; i < bucket.values.length; i++)
        {
            output ~= TextEncoding.encodeMetricLine(
                this.name ~ "_bucket",
                this.labels ~ "le",
                labelValues ~ this.bucketValueString(i),
                bucket.values[i],
                this.timestamp);
        }

        output ~= TextEncoding.encodeMetricLine(
            this.name ~ "_sum",
            this.labels,
            labelValues,
            bucket.sum,
            this.timestamp);

        output ~= TextEncoding.encodeMetricLine(
            this.name ~ "_count",
            this.labels,
            labelValues,
            bucket.values[bucket.values.length-1],
            this.timestamp);
    }

    private string bucketValueString(int idx) {
        return TextEncoding.encodeNumber(
            idx < this.bucketValues.length ?
                this.bucketValues[idx] :
                double.infinity
        );
    }
}
