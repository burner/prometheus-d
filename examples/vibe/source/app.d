import prometheus.counter;
import prometheus.gauge;
import prometheus.registry;
import prometheus.vibe;

import core.memory : GC;
import core.thread : Thread;

import std.datetime : seconds;

import vibe.d;

void main()
{
    auto settings = new HTTPServerSettings;
    settings.port = 8080;

    //create counter and register with global registry
    Counter c = new Counter("hit_count", "Shows the number of site hits", null);
    c.register;

    Gauge gu = new Gauge("memory_usage", null, null);
    gu.register;
    Gauge gr = new Gauge("memory_reserve", null, null);
    gr.register;

    Thread t = new Thread(() {

        while(true)
        {
            auto stats = GC.stats;

            gu.set(stats.usedSize);
            gr.set(stats.usedSize + stats.freeSize);

            Thread.sleep(1.seconds);
        }
    });
    t.start;

    //start routes for Vibe.d
    auto router = new URLRouter;
    router.any("*", (HTTPServerRequest req, HTTPServerResponse res) {
        c.inc;
    });
    router.get("/", (HTTPServerRequest req, HTTPServerResponse res) {
        res.writeBody("hello, world!");
    });
    router.get("/metrics", handleMetrics(Registry.global));

    listenHTTP(settings, router);
    runApplication;
}
