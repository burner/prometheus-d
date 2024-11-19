/*
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/.
 */

module prometheus.metric;

import core.time : convert;
import std.datetime : Clock, DateTime, SysTime, UTC;

import prometheus.registry;

@safe:

abstract class Metric
{
    string name;
    string help;
    string[] labels;

    void observe(double value, string[] labelValues);

    MetricSnapshot collect();

    Metric register() @system
    {
        return this.register(Registry.global);
    }

    Metric register(Registry reg)
    {
        reg.register(this);
        return this;
    }

    /// I hate this hack, but it's what I have
    final static long posixTime()
    {
        enum posixEpochAsStd = SysTime(
            DateTime(1970, 1, 1, 0, 0, 0),
            UTC()
        ).stdTime;

        return (Clock.currTime.toUTC.stdTime - posixEpochAsStd).convert!("hnsecs", "msecs");
    }
}

enum EncodingFormat
{
    text,
    proto
}

abstract class MetricSnapshot
{
    string encode(EncodingFormat fmt = EncodingFormat.text);
}
