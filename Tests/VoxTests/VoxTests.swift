import Foundation

extension Int {
    mutating func invoke() {
        self += 1
    }
    
    var isInvokedOnce: Bool {
        return self == 1
    }
}

extension Data {
    init(jsonFileName: String) {
        let url = Bundle.module.url(forResource: jsonFileName, withExtension: "json")!
        
        self = try! Data(contentsOf: url)
    }
}
