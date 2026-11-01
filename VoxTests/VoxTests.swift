import Foundation

extension Int {
    mutating func invoke() {
        self += 1
    }
    
    var isInvokedOnce: Bool {
        return self == 1
    }
}

private final class BundleToken {}

extension Data {
    init(jsonFileName: String) {
        let url = Bundle(for: BundleToken.self).url(forResource: jsonFileName, withExtension: "json")!
        
        self = try! Data(contentsOf: url)
    }
}
