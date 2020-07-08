//
//  ViewController.swift
//  BatteryTester
//
//  Created by Rocco Bowling on 6/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable function_body_length
// swiftlint:disable cyclomatic_complexity

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

    var counters: [Counter] = []

    func adjustCounters(_ num: Int) {
        guard let sleepSlider = sleepSlider else { return }
        guard let coreAffinity = coreAffinity else { return }

        let sleepAmount = UInt32(sleepSlider.value)
        let qos = Int(coreAffinity.selectedSegmentIndex)
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
        }

        UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).numberOfLines = 0
        coreAffinity.insertSegment(withTitle: "Prefer Efficiency", at: 0, animated: false)
        coreAffinity.insertSegment(withTitle: "Prefer Performance", at: 1, animated: false)
        coreAffinity.insertSegment(withTitle: "Only Efficiency", at: 2, animated: false)
        coreAffinity.insertSegment(withTitle: "Only Performance", at: 3, animated: false)
        coreAffinity.selectedSegmentIndex = 0

        coreAffinity.add(for: .valueChanged) { [weak self] in
            guard let self = self else { return }
            let qos = Int(coreAffinity.selectedSegmentIndex)
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
    }

}
