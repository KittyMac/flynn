## BatteryTester

This example uses actors to perform continuous busy work in order to demonstrate the core affinity feature.

Any actor in Flynn can be assigned a core affinity by doing:

```actor.unsafeCoreAffinity = .preferEfficiency```

For complete details, please see the [Actor Scheduling](../../docs/SCHEDULER.md) documentation.


### Benchmark

Wondering what the realistic difference in battery life there is between running on the "efficiency" cores vs the "performance" cores on Apple Silicon?  Well, look no further.  With Flynn and this Battery Tester sample we can measure the amount of time it takes to drain the battery a specific amount.

To do this just set the number of actors and core affinity you want to test, then press "Run Benchmark".  The device battery level will be monitored; when it drops 10% from its starting level the benchmark will stop and a time will be displayed on the screen.

The following simple test was performed on an iPhone 8+.  The screen brightness was set to minimum, and both tests were begun with the device at 100% charge, both tests stopped when device reached 90% charge.

| Number of Cores      |  Time in seconds  | Time in mintues
|----------------------|-------------------|------------------|
|  2 Efficiency Cores  |  2884.95 sec      | 48.08 min        |
|  2 Performance Cores |  1243.90 sec      | 20.73 min        |

While your mileage may vary, it is encouraging to see that running on the efficiency cores vs the performance cores provided a **2.3x reduction** in battery consumptions due to CPU usage.



![](meta/screenshot.png)
