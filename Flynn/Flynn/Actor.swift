//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

open class Actor {
    internal let uuid:String!
    internal let messages:OperationQueue!
    
    // While not 100% accurate, it can be helpful to know how large the
    // actor's mailbox size is in order to perform lite load balancing
    var messagesCount:Int {
        get {
            return messages.operationCount
        }
    }
    
    func yield(_ ms:Int) {
        // stop processing messages for ms number of milliseconds
        messages.isSuspended = true
        let deadlineTime = DispatchTime.now() + .milliseconds(ms)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            self.messages.isSuspended = false
        }
    }
    
    public init() {
        uuid = UUID().uuidString
        messages = OperationQueue()
        messages.qualityOfService = .userInteractive
        messages.maxConcurrentOperationCount = 1
    }
}

