import Flynn
import WebKit

class SecondActor: Actor {
    
    internal func _beTest() {
        print("Hello World!")
    }
    
    internal func _beTestStruct(value: WKWebView) {
        
    }
    
    private func bar() {
        self._beTest()
    }
}
