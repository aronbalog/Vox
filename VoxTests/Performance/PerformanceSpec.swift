import Foundation
import XCTest

@testable import Vox

fileprivate class SomeResource: Resource {
    override class var resourceType: String {
        return "SomeResource"
    }
    
    // attributes
    @objc dynamic var string: String?
    @objc dynamic var isActive: NSNumber?
    @objc dynamic var array: [String]?
    
    // relationships
    @objc dynamic var parent: SomeResource?
}

class PerformanceSpec: XCTestCase {
    private static let resourceCount = 5_000
    
    /// A collection document in which every resource points to its predecessor.
    private lazy var data: Data = {
        let resources: [[String: Any]] = (0..<Self.resourceCount).map { index in
            var resource: [String: Any] = [
                "type": SomeResource.resourceType,
                "id": "\(index)",
                "attributes": [
                    "string": "Resource \(index)",
                    "isActive": index % 2 == 0,
                    "array": ["a", "b", "c"]
                ]
            ]
            
            if index > 0 {
                resource["relationships"] = [
                    "parent": [
                        "data": ["type": SomeResource.resourceType, "id": "\(index - 1)"]
                    ]
                ]
            }
            
            return resource
        }
        
        return try! JSONSerialization.data(withJSONObject: ["data": resources])
    }()
    
    func testDeserializationPerformance() {
        let sut = Deserializer.Collection<SomeResource>()
        let data = self.data
        
        measure {
            _ = try! sut.deserialize(data: data)
        }
    }
    
    func testAttributeAccessPerformance() throws {
        let document = try Deserializer.Collection<SomeResource>().deserialize(data: data)
        let resources = try XCTUnwrap(document.data)
        
        measure {
            for resource in resources {
                _ = resource.string
                _ = resource.isActive
                _ = resource.array
                _ = resource.parent?.id
            }
        }
    }
}
