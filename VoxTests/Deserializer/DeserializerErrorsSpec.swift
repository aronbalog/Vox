import UIKit
import Quick
import Nimble

@testable import Vox

fileprivate class MockClass: Resource {
    override class var resourceType: String {
        return "mock"
    }
}

class DeserializerErrorsSpec: QuickSpec {
    
    override func spec() {
        let sut = Deserializer.Single<MockClass>()
        
        describe("Deserializer") {
            
            context("when deserializing single resource and error data provided", {
                context("with source object included in errors", {
                    let data = Data(jsonFileName: "ErrorsWithSource")

                    var expectedErrors: [ErrorObject]?
                    
                    do {
                        _ = try sut.deserialize(data: data)
                    } catch JSONAPIError.API(let errors) {
                        expectedErrors = errors
                    } catch {
                        
                    }
                    
                    it("maps to errors object", closure: {
                        expect(expectedErrors?.count).to(equal(1))
                        
                        let errorObject = expectedErrors!.first!
                        
                        expect(errorObject.status).to(equal("422"))
                        expect(errorObject.source?.pointer).to(equal("/data/attributes/first-name"))
                        expect(errorObject.title).to(equal("Invalid Attribute"))
                        expect(errorObject.detail).to(equal("First name must contain at least three characters."))
                    })
                })
                
                context("with source object included in errors", {
                    let data = Data(jsonFileName: "ErrorsWithoutSource")
                    
                    var expectedErrors: [ErrorObject]?
                    
                    do {
                        _ = try sut.deserialize(data: data)
                    } catch JSONAPIError.API(let errors) {
                        expectedErrors = errors
                    } catch {
                        
                    }
                    
                    it("maps to errors object", closure: {
                        expect(expectedErrors?.count).to(equal(1))
                        
                        let errorObject = expectedErrors!.first!
                        
                        expect(errorObject.status).to(equal("422"))
                        expect(errorObject.source).to(beNil())
                        expect(errorObject.title).to(equal("Invalid Attribute"))
                        expect(errorObject.detail).to(equal("First name must contain at least three characters."))
                    })
                })
                
            })
        }
    }
}

