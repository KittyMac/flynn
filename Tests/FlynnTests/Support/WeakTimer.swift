import XCTest

@testable import Flynn

class WeakTimer: Actor {
    private var timer: Flynn.Timer?
    
    deinit {
        print("WeakTimer -> deinit")
    }
    
    override init() {
        super.init()
        
        var count = 0
        timer = Flynn.Timer(timeInterval: 1, repeats: true, self) { [weak self] _ in
            guard let _ = self else { return }
            print("timer \(count)")
            count += 1
        }
    }
}
