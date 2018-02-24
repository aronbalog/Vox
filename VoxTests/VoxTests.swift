import Foundation

extension Int {
    mutating func invoke() {
        self += 1
    }
    
    var isInvokedOnce: Bool {
        return self == 1
    }
}

fileprivate class FakeClass {}

extension Data {
    init(jsonFileName: String) {
        let path = Bundle(for: FakeClass.self).url(forResource: jsonFileName, withExtension: "json")!
        
        
        self = try! Data(contentsOf: path)
    }
}

