import UIKit
import Quick
import Nimble

@testable import Vox

fileprivate class SomeResource: Resource {
    override class var resourceType: String {
        return "SomeResource"
    }
    
    // attributes
    @objc dynamic var string: String?
    @objc dynamic var isActive: NSNumber?
    @objc dynamic var array: [String]?
}

class PerformanceSpec: XCTestCase {
    lazy var data = Data(jsonFileName: "Big")

    func testPerformance() {
        let sut = Deserializer.Collection<SomeResource>()
        
        measure {
            _ = try! sut.deserialize(data: self.data)
        }
    }
}
