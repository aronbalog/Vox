import Foundation
import Testing

@testable import Vox

fileprivate class MockClass: Resource {
    override class var resourceType: String {
        return "mock"
    }
}

@Suite("Deserializer when deserializing single resource and error data provided")
struct DeserializerErrorsSpec {
    private func decodedErrors(inFixture name: String) throws -> [ErrorObject] {
        do {
            _ = try Deserializer.Single<MockClass>().deserialize(data: Data(jsonFileName: name))
        } catch JSONAPIError.API(let errors) {
            return errors
        }
        
        Issue.record("Expected JSONAPIError.API to be thrown")
        return []
    }
    
    @Test("with source object included in errors maps to errors object")
    func errorsWithSource() throws {
        let errors = try decodedErrors(inFixture: "ErrorsWithSource")
        #expect(errors.count == 1)
        
        let errorObject = try #require(errors.first)
        #expect(errorObject.status == "422")
        #expect(errorObject.source?.pointer == "/data/attributes/first-name")
        #expect(errorObject.title == "Invalid Attribute")
        #expect(errorObject.detail == "First name must contain at least three characters.")
    }
    
    @Test("without source object included in errors maps to errors object")
    func errorsWithoutSource() throws {
        let errors = try decodedErrors(inFixture: "ErrorsWithoutSource")
        #expect(errors.count == 1)
        
        let errorObject = try #require(errors.first)
        #expect(errorObject.status == "422")
        #expect(errorObject.source == nil)
        #expect(errorObject.title == "Invalid Attribute")
        #expect(errorObject.detail == "First name must contain at least three characters.")
    }
}
