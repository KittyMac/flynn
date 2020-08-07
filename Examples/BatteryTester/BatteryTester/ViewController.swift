//
//  ViewController.swift
//  BatteryTester
//
//  Created by Rocco Bowling on 6/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable function_body_length
// swiftlint:disable cyclomatic_complexity

// Benchmark Results:
// Performed on iPhone 8+
// Screen brightness to minimum

// 100% CPU usage on 2 Efficiency Cores: 100% -> 90% battery in 2884.95 seconds
// 100% CPU usage on 2 Performance Cores: 100% -> 90% battery in 1243.90 seconds

import UIKit
import PlanetSwift
import Anchorage
import Flynn

class ViewController: PlanetViewController {

    @objc dynamic var countTotal: UILabel?
    @objc dynamic var countPerTimeUnit: UILabel?
    @objc dynamic var actorLabel: UILabel?
    @objc dynamic var sleepLabel: UILabel?
    @objc dynamic var actorSlider: UISlider?
    @objc dynamic var sleepSlider: UISlider?
    @objc dynamic var coreAffinity: UISegmentedControl?
    @objc dynamic var benchButton: UIButton?
    @objc dynamic var benchButtonLabel: UILabel?
    @objc dynamic var benchResultsLabel: UILabel?

    var benchmarkRunning = false
    var benchmarkStartTime = ProcessInfo.processInfo.systemUptime
    var benchmarkStartBattery = UIDevice.current.batteryLevel

    var counters: [Counter] = []

    func adjustCounters(_ num: Int) {
        guard let sleepSlider = sleepSlider else { return }
        guard let coreAffinity = coreAffinity else { return }

        let sleepAmount = UInt32(sleepSlider.value)
        let qos = Int32(coreAffinity.selectedSegmentIndex)
        while counters.count < num {
            counters.append(Counter(sleepAmount, qos))
        }
        while counters.count > num {
            counters.removeFirst().beStop()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Battery Tester"

        UIDevice.current.isBatteryMonitoringEnabled = true

        persistentViews = false
        navigationBarHidden = true
        mainBundlePath = "bundle://Assets/Main/Main.xml"

        loadPlanetViews { (_, view, parent, prev, _, _) in

            view.centerXAnchor == parent.centerXAnchor

            switch view {
            case self.coreAffinity:
                view.centerXAnchor == parent.centerXAnchor
                view.widthAnchor == parent.widthAnchor - 40
                view.topAnchor == prev!.bottomAnchor + 80
                view.heightAnchor == 60

            case self.countTotal:
                view.topAnchor == parent.topAnchor + 80
                view.widthAnchor == parent.widthAnchor - 80

            case self.actorLabel, self.sleepLabel:
                view.topAnchor == prev!.bottomAnchor + 80
                view.widthAnchor == parent.widthAnchor - 80

            case self.countPerTimeUnit, self.actorSlider, self.sleepSlider:
                view.topAnchor == prev!.bottomAnchor + 10
                view.widthAnchor == parent.widthAnchor - 80

            case self.benchButton:
                view.topAnchor == prev!.bottomAnchor + 16
                view.widthAnchor == 280
                view.heightAnchor == 60

            case self.benchResultsLabel:
                view.topAnchor == prev!.bottomAnchor + 16
                view.widthAnchor == parent.widthAnchor - 80
                view.heightAnchor == 20

            default:
                view.sizeAnchors == parent.sizeAnchors
                return
            }
        }

        guard let countTotal = countTotal else { return }
        guard let countPerTimeUnit = countPerTimeUnit else { return }
        guard let coreAffinity = coreAffinity else { return }
        guard let actorSlider = actorSlider else { return }
        guard let sleepSlider = sleepSlider else { return }
        guard let actorLabel = actorLabel else { return }
        guard let sleepLabel = sleepLabel else { return }
        guard let benchButton = benchButton else { return }
        guard let benchButtonLabel = benchButtonLabel else { return }
        guard let benchResultsLabel = benchResultsLabel else { return }

        let updateFrequency = 1.0 / 60.0

        var countsPerTime: Int = 0
        var countPerTimeTimer: Double = 0

        Timer.scheduledTimer(withTimeInterval: updateFrequency, repeats: true) { (_) in
            let total = self.counters.reduce(0) { result, counter in result + counter.unsafeCount }
            countTotal.text = String(total)

            countPerTimeTimer += updateFrequency
            if countPerTimeTimer > 1.0 {
                countPerTimeUnit.text = "\( (total - countsPerTime)) per second"

                countsPerTime = total
                countPerTimeTimer -= 1.0
            }

            UIApplication.shared.isIdleTimerDisabled = self.benchmarkRunning

            if self.benchmarkRunning == false {
                benchButtonLabel.text = "Start Benchmark"
            } else {
                let runtime = ProcessInfo.processInfo.systemUptime - self.benchmarkStartTime
                let batteryLost = self.benchmarkStartBattery - UIDevice.current.batteryLevel
                let batteryLostPercent = self.toPerc(batteryLost)
                benchButtonLabel.text = "Benchmark Running..."
                benchResultsLabel.text = String(format: "Runtime: %0.2fs Battery Loss: %d%%",
                                                runtime,
                                                batteryLostPercent)

                if batteryLostPercent >= 10 {
                    self.stopBenchmark()
                }
            }
        }

        UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).numberOfLines = 0
        coreAffinity.insertSegment(withTitle: "Prefer Efficiency", at: 0, animated: false)
        coreAffinity.insertSegment(withTitle: "Prefer Performance", at: 1, animated: false)
        coreAffinity.insertSegment(withTitle: "Only Efficiency", at: 2, animated: false)
        coreAffinity.insertSegment(withTitle: "Only Performance", at: 3, animated: false)
        coreAffinity.selectedSegmentIndex = 0

        coreAffinity.add(for: .valueChanged) { [weak self] in
            guard let self = self else { return }
            let qos = Int32(coreAffinity.selectedSegmentIndex)
            _ = self.counters.map { $0.beSetCoreAffinity(qos) }
        }

        actorSlider.add(for: .valueChanged) { [weak self] in
            guard let self = self else { return }
            let numActors = Int(actorSlider.value)
            self.adjustCounters(numActors)
            actorLabel.text = "\(numActors) actors"
        }

        sleepSlider.add(for: .valueChanged) { [weak self] in
            guard let self = self else { return }
            let sleepAmount = UInt32(sleepSlider.value)
            _ = self.counters.map { $0.unsafeSleepAmount = sleepAmount }
            sleepLabel.text = "\(sleepAmount) µs sleep"
        }

        benchButton.add(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.toggleBenchmark()
        }
    }

    func startBenchmark() {
        benchmarkRunning = true
        benchmarkStartTime = ProcessInfo.processInfo.systemUptime
        benchmarkStartBattery = UIDevice.current.batteryLevel
    }

    func stopBenchmark() {
        benchmarkRunning = false
        print("Battery Benchmark Aborted")
        print("=========================")

        let runtime = ProcessInfo.processInfo.systemUptime - benchmarkStartTime
        print("runtime: \(runtime) seconds")

        let battery = UIDevice.current.batteryLevel
        print("battery start: \( toPerc(benchmarkStartBattery) )%")
        print("battery end: \( toPerc(battery) )%")
        print("battery lost: \( toPerc(benchmarkStartBattery - battery) )%")
    }

    func toggleBenchmark() {
        if benchmarkRunning {
            stopBenchmark()

        } else {
            startBenchmark()
        }
    }

    func toPerc(_ value: Float) -> Int {
        return Int(value * 100)
    }

}
