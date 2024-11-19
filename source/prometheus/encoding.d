module prometheus.encoding;

import std.algorithm.iteration : map;
import std.format : format;
import std.functional : pipe;
import std.math : isInfinity, isNaN, sgn;
import std.range : zip;
import std.string : replace, strip, stripRight;

@safe:

class TextEncoding
{
@safe:
    alias encodeKey = pipe!(
        (string s) { return replace(s, `\`, `\\`); },
        (string s) { return replace(s, "\n", `\n`); },
    );

    static string encodeType(string name, string type)
    {
        return "# TYPE %s %s\n".format(encodeKey(name), type);
    }

    static string encodeHelp(string name, string help)
    {
        return "# HELP %s %s\n".format(encodeKey(name), encodeKey(help));
    }

    alias encodeLabelValue = pipe!(
        encodeKey,
        (string s) { return replace(s, `"`, `\"`); }
    );

    static string encodeNumber(double value)
    {
        if(value == 0) {
            return "0";
		} else if(value.isNaN) {
            return "Nan";
		} else if(value.isInfinity) {
            return value.sgn > 0 ? "+Inf" : "-Inf";
		}

        return "%f".format(value).strip("0").stripRight(".");
    }

    static string encodeLabels(const string[] labels, const string[] labelValues)
    {
        if(labels is null || labels.length < 1) {
            return "";
		} else {
            return "{%-(%s,%)}".format(zip(labels, labelValues).
                map!(t => "%s=\"%s\"".format(
                    TextEncoding.encodeKey(t[0]),
                    TextEncoding.encodeLabelValue(t[1])
                )
            ));
        }
    }

    static string encodeMetricLine(const string name, const string[] labels, const string[] labelValues, double value, long timestamp)
    {
        return "%s%s %s %d\n".format(
            encodeKey(name),
            encodeLabels(labels, labelValues),
            encodeNumber(value),
            timestamp
        );
    }
}

unittest
{
    //usual cases
    assert(TextEncoding.encodeNumber(0.0) == "0");
    assert(TextEncoding.encodeNumber(1.0) == "1");
    assert(TextEncoding.encodeNumber(1.1) == "1.1");
    assert(TextEncoding.encodeNumber(-1.1) == "-1.1");
    assert(TextEncoding.encodeNumber(1000000000.1234) == "1000000000.1234");
    assert(TextEncoding.encodeNumber(-00000000.12348) == "-0.12348");

    //unusual cases
    assert(TextEncoding.encodeNumber(float.infinity) == "+Inf");
    assert(TextEncoding.encodeNumber(-float.infinity) == "-Inf");
    assert(TextEncoding.encodeNumber(float.nan) == "Nan");
}

unittest
{
    assert(TextEncoding.encodeMetricLine("test", [], [], 0.0, 0) == "test 0 0\n");
    assert(TextEncoding.encodeMetricLine("test", [], [], 1.0, 0) == "test 1 0\n");
    assert(TextEncoding.encodeMetricLine("test", ["a"], ["b"], 0.0, 0) == "test{a=\"b\"} 0 0\n");
}

unittest
{
    assert(TextEncoding.encodeLabels([], []) == "");
    assert(TextEncoding.encodeLabels(["a"], ["b"]) == "{a=\"b\"}");
}
