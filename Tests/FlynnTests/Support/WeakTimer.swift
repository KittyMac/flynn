import XCTest

@testable import Flynn

class WeakTimer: Actor {
    private var timer: Flynn.Timer?
    
    deinit {
        print("WeakTimer -> deinit")
    }
    
    override init() {
        super.init()
        
        Flynn.dock(self)
        
        var count = 0
        timer = Flynn.Timer(timeInterval: 1, repeats: true, self) { [weak self] _ in
            guard let self = self else { return }
            print("timer \(count)")
            count += 1
            
            if count == 3 {
                Flynn.undock(self)
            }
        }
    }
}
