import XCTest

import Flynn

public extension Encodable {
    func json(pretty: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? #"{"error":"failed to convert string to utf8"}"#
    }
}

class ProfilerBusyActor: Actor {
    private var work: Double = 0

    internal func _beWork() {
        var acc = work
        for i in 0..<60_000 {
            acc += sin(Double(i) * 0.001) * cos(Double(i) * 0.002)
        }
        work = acc
    }

    internal func _beResult(_ callback: @escaping (Double) -> Void) {
        callback(work)
    }
}

class ProfilerLightActor: Actor {
    private var count: Int = 0

    internal func _beWork() {
        count &+= 1
    }

    internal func _beResult(_ callback: @escaping (Int) -> Void) {
        callback(count)
    }
}


final class FlynnProfilerTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.Profiler.stop()
        Flynn.shutdown()
    }

    private func sample(_ type: String,
                        in samples: [Flynn.Profiler.Sample]) -> Flynn.Profiler.Sample? {
        return samples.first { $0.type == type }
    }

    func testProfilerRanksBusyActorAboveLightActor() {
        Flynn.Profiler.start()
        Flynn.Profiler.reset()

        let busy = ProfilerBusyActor()
        let light = ProfilerLightActor()

        let messageCount = 200
        for _ in 0..<messageCount {
            busy.beWork()
            light.beWork()
        }

        busy.unsafeWait()
        light.unsafeWait()

        let samples = Flynn.Profiler.collect()
        
        if let json = try? samples.json(pretty: true) {
            print(json)
        }
        
        print(Flynn.Profiler.description())

        guard let busySample = sample("ProfilerBusyActor", in: samples) else {
            return XCTFail("ProfilerBusyActor was not tracked by the profiler")
        }
        guard let lightSample = sample("ProfilerLightActor", in: samples) else {
            return XCTFail("ProfilerLightActor was not tracked by the profiler")
        }

        XCTAssertGreaterThan(busySample.batches, 0)
        XCTAssertGreaterThan(lightSample.batches, 0)
        XCTAssertGreaterThan(busySample.totalNanoseconds, 0)
        XCTAssertGreaterThan(busySample.totalNanoseconds, lightSample.totalNanoseconds,
                             "heavy actor should consume more scheduler time than the light one")

        XCTAssertEqual(samples.first?.type, "ProfilerBusyActor")

        let workRead = expectation(description: "read work")
        busy.beResult { value in
            XCTAssertNotEqual(value, 0)
            workRead.fulfill()
        }
        wait(for: [workRead], timeout: 10.0)
    }

    func testProfilerResetClearsSamples() {
        Flynn.Profiler.start()
        Flynn.Profiler.reset()

        let busy = ProfilerBusyActor()
        for _ in 0..<50 { busy.beWork() }
        busy.unsafeWait()

        XCTAssertNotNil(sample("ProfilerBusyActor", in: Flynn.Profiler.collect()),
                        "expected samples before reset")

        Flynn.Profiler.reset()

        let afterReset = sample("ProfilerBusyActor", in: Flynn.Profiler.collect())
        XCTAssertNil(afterReset, "reset() should have cleared all samples")
    }

    func testProfilerDisabledDoesNotTrackNewActors() {
        Flynn.Profiler.stop()
        Flynn.Profiler.reset()

        let busy = ProfilerBusyActor()
        for _ in 0..<50 { busy.beWork() }
        busy.unsafeWait()

        XCTAssertNil(sample("ProfilerBusyActor", in: Flynn.Profiler.collect()),
                     "actors created while profiling is disabled should not be tracked")
    }
}
