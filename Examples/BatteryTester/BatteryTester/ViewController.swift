//
//  ViewController.swift
//  BatteryTester
//
//  Created by Rocco Bowling on 6/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable function_body_length

import UIKit
import PlanetSwift
import Anchorage
import Flynn

class Counter: Actor {
    public var unsafeCount: Int = 0
    public var unsafeSleepAmount: UInt32 = 0

    private var done: Bool = false
    private let batchCount: Int = 100000

    init(_ sleepAmount: UInt32, _ qos: Int32) {
        super.init()

        if let qos = CoreAffinity(rawValue: qos) {
            safeCoreAffinity = qos
        }

        unsafeSleepAmount = sleepAmount

        beCount()
    }

    private func count() {
        for _ in 0..<batchCount {
            unsafeCount += 1
        }
        if done == false {
            if unsafeSleepAmount > 0 {
                usleep(unsafeSleepAmount)
            }
            self.beCount()
        }
    }

    lazy var beCount = Behavior(self) { (_ : BehaviorArgs) in
        self.count()
    }

    lazy var beStop = Behavior(self) { (_ : BehaviorArgs) in
        self.done = true
    }

    lazy var beSetCoreAffinity = Behavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Int32 - quality of service
        if let qos = CoreAffinity(rawValue: args[x:0]) {
            self.safeCoreAffinity = qos
        }
    }
}

class ViewController: PlanetViewController {

    var counters: [Counter] = []

    func adjustCounters(_ num: Int) {
        let sleepAmount = UInt32(self.sleepSlider.localSlider.value)
        let qos = Int32(self.coreAffinity.segmentedControl.selectedSegmentIndex)
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

        persistentViews = false
        navigationBarHidden = true
        mainBundlePath = "bundle://Assets/Main/Main.xml"

        loadPlanetViews { (name, view, parent, prev, _, _) in
            if name == "root" || name == "background" {
                view.sizeAnchors == parent.sizeAnchors
                return
            }

            if name == "coreAffinity" {
                view.centerXAnchor == parent.centerXAnchor
                view.widthAnchor == parent.widthAnchor - 40
                view.topAnchor == prev!.bottomAnchor + 80
                view.heightAnchor == 60
                return
            }

            if name == "countTotal" {
                view.topAnchor == parent.topAnchor + 80
            }

            view.centerXAnchor == parent.centerXAnchor
            view.widthAnchor == parent.widthAnchor - 80

            if  name == "actorLabel" ||
                name == "sleepLabel" {
                view.topAnchor == prev!.bottomAnchor + 80
            }
            if  name == "countPerTimeUnit" ||
                name == "actorSlider" ||
                name == "sleepSlider" {
                view.topAnchor == prev!.bottomAnchor + 10
            }
        }

        let updateFrequency = 1.0 / 60.0

        let countTotalLabel = countTotal.label
        let countPerTimeUnitLabel = countPerTimeUnit.label

        var countsPerTime: Int = 0
        var countPerTimeTimer: Double = 0

        Timer.scheduledTimer(withTimeInterval: updateFrequency, repeats: true) { (_) in
            let total = self.counters.reduce(0) { result, counter in result + counter.unsafeCount }
            countTotalLabel.text = String(total)

            countPerTimeTimer += updateFrequency
            if countPerTimeTimer > 1.0 {
                countPerTimeUnitLabel.text = "\( (total - countsPerTime)) per second"

                countsPerTime = total
                countPerTimeTimer -= 1.0
            }
        }

        UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).numberOfLines = 0
        coreAffinity.segmentedControl.insertSegment(withTitle: "Prefer Efficiency", at: 0, animated: false)
        coreAffinity.segmentedControl.insertSegment(withTitle: "Prefer Performance", at: 1, animated: false)
        coreAffinity.segmentedControl.insertSegment(withTitle: "Only Efficiency", at: 2, animated: false)
        coreAffinity.segmentedControl.insertSegment(withTitle: "Only Performance", at: 3, animated: false)
        coreAffinity.segmentedControl.selectedSegmentIndex = 0

        coreAffinity.segmentedControl.add(for: .valueChanged) { [weak self] in
            guard let self = self else { return }
            let qos = Int(self.coreAffinity.segmentedControl.selectedSegmentIndex)
            _ = self.counters.map { $0.beSetCoreAffinity(qos) }
        }

        actorSlider.localSlider.add(for: .valueChanged) { [weak self] in
            guard let self = self else { return }
            let numActors = Int(self.actorSlider.localSlider.value)
            self.adjustCounters(numActors)
            self.actorLabel.label.text = "\(numActors) actors"
        }

        sleepSlider.localSlider.add(for: .valueChanged) { [weak self] in
            guard let self = self else { return }
            let sleepAmount = UInt32(self.sleepSlider.localSlider.value)
            _ = self.counters.map { $0.unsafeSleepAmount = sleepAmount }
            self.sleepLabel.label.text = "\(sleepAmount) µs sleep"
        }
    }

    fileprivate var countTotal: Label {
        return mainXmlView!.elementForId("countTotal")!.asLabel!
    }

    fileprivate var countPerTimeUnit: Label {
        return mainXmlView!.elementForId("countPerTimeUnit")!.asLabel!
    }

    fileprivate var actorLabel: Label {
        return mainXmlView!.elementForId("actorLabel")!.asLabel!
    }

    fileprivate var sleepLabel: Label {
        return mainXmlView!.elementForId("sleepLabel")!.asLabel!
    }

    fileprivate var actorSlider: Slider {
        return mainXmlView!.elementForId("actorSlider")!.asSlider!
    }

    fileprivate var sleepSlider: Slider {
        return mainXmlView!.elementForId("sleepSlider")!.asSlider!
    }

    fileprivate var coreAffinity: SegmentedControl {
        return mainXmlView!.elementForId("coreAffinity")!.asSegmentedControl!
    }

}
