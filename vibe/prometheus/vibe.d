/*
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/.
 */

module prometheus.vibe;

import prometheus.metric;
import prometheus.registry;

import vibe.http.server;

@safe:
void delegate(HTTPServerRequest, HTTPServerResponse) handleMetrics(Registry reg)
{
    return (HTTPServerRequest, HTTPServerResponse res) @safe {
        string data;

        res.contentType = "text/plain";
		auto bw = res.bodyWriter();

        foreach(m; reg.metrics)
        {
            bw.write(m.collect().encode(EncodingFormat.text));
            bw.write("\n");
        }
    };
}
