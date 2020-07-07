//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !os(Linux)
struct Sysctl {
    static subscript<T>(_ key: String) -> T? {
        get {
            var len: Int = 0
            if sysctlbyname(key, nil, &len, nil, 0) == 0 {

                switch T.self {
                case is UInt32.Type:
                    var value = CUnsignedInt()
                    sysctlbyname(key, &value, &len, nil, 0)
                    //print(key, ":", value)
                    return UInt32(value) as? T
                case is Int.Type:
                    var value = CInt()
                    sysctlbyname(key, &value, &len, nil, 0)
                    //print(key, ":", value)
                    return Int(value) as? T
                case is Int64.Type:
                    var value = CLong()
                    sysctlbyname(key, &value, &len, nil, 0)
                    //print(key, ":", value)
                    return Int64(value) as? T
                case is String.Type:
                    var value = [CChar](repeating: 0, count: Int(len))
                    sysctlbyname(key, &value, &len, nil, 0)
                    let string = String(cString: value)
                    //print(key, ":", string)
                    return string as? T
                default:
                    return nil
                }
            }

            return nil
        }
        set { }
    }
}
#endif

open class Device {

    var cores: Int = 0   // The number of hardware cores on this device

    var eCores: Int = 0   // The number of efficiency cores on this device
    var pCores: Int = 0   // The number of performance cores on this device

    init() {
        #if os(Linux)
        cores = ProcessInfo.processInfo.processorCount
        #else
        cores = Sysctl["hw.physicalcpu"] ?? 0

        let cpuFamily: UInt32 = Sysctl["hw.cpufamily"] ?? 0
        switch UInt32(cpuFamily) {
        case UInt32(CPUFAMILY_ARM_MONSOON_MISTRAL):
            /* 2x Monsoon + 4x Mistral cores */
            eCores = 4
            pCores = 2
        case UInt32(CPUFAMILY_ARM_VORTEX_TEMPEST), UInt32(CPUFAMILY_ARM_LIGHTNING_THUNDER):
            /* Hexa-core: 2x Vortex + 4x Tempest; Octa-core: 4x Cortex + 4x Tempest */
            /* Hexa-core: 2x Lightning + 4x Thunder; Octa-core (presumed): 4x Lightning + 4x Thunder */
            if cores == 6 {
                eCores = 4
                pCores = 2
            }
            if cores == 8 {
                eCores = 4
                pCores = 4
            }
        default:
            break
        }
        #endif

        if eCores + pCores != cores {
            pCores = cores / 2
            eCores = cores - pCores
        }

        if pCores == 0 {
            pCores = 1
        }
        if eCores == 0 {
            eCores = 1
        }

        cores = eCores + pCores

        //print("cores: \(cores)")
        //print("ecores: \(eCores)")
        //print("pcores: \(pCores)")
    }

}
