import Foundation
import Testing

@testable import Vox

fileprivate final class Event: Resource {
    override class var resourceType: String {
        return "date-events"
    }
    
    var startsAt: Date?
    var website: URL?
}

@Suite("Date and URL attributes")
struct DateAttributeSpec {
    private func event(attributes: String) throws -> Event {
        ResourceRuntime.register(Event.self)
        let json = #"{ "data": { "type": "date-events", "id": "1", "attributes": \#(attributes) } }"#
        
        return try #require(try Deserializer.Single<Event>().deserialize(data: Data(json.utf8)).data)
    }
    
    @Test("ISO 8601 date-times and dates are decoded", arguments: [
        ("2024-01-31T10:20:30Z", 728_389_230.0),
        ("2024-01-31T12:20:30+02:00", 728_389_230.0),
        ("2024-01-31T10:20:30.250Z", 728_389_230.25),
        ("2024-01-31", 728_352_000.0)
    ])
    func decoding(string: String, timeIntervalSinceReferenceDate: TimeInterval) throws {
        let event = try event(attributes: #"{ "startsAt": "\#(string)" }"#)
        let date = try #require(event["startsAt"] as? Date)
        
        #expect(abs(date.timeIntervalSinceReferenceDate - timeIntervalSinceReferenceDate) < 0.001)
    }
    
    @Test("strings that aren't dates read as nil")
    func invalidDates() throws {
        #expect(try event(attributes: #"{ "startsAt": "tomorrow" }"#)["startsAt"] == nil)
        #expect(try event(attributes: #"{ "startsAt": 1706696430 }"#)["startsAt"] == nil)
    }
    
    @Test("dates are encoded as UTC date-times")
    func encoding() {
        let event = Event()
        
        event["startsAt"] = Date(timeIntervalSinceReferenceDate: 728_389_230)
        #expect(event.attributes["startsAt"] as? String == "2024-01-31T10:20:30Z")
        
        event["startsAt"] = Date(timeIntervalSinceReferenceDate: 728_389_230.5)
        #expect(event.attributes["startsAt"] as? String == "2024-01-31T10:20:30.500Z")
    }
    
    @Test("URLs are decoded from and encoded as strings")
    func urls() throws {
        let event = try event(attributes: #"{ "website": "https://example.com/events/1" }"#)
        #expect(event["website"] as? URL == URL(string: "https://example.com/events/1"))
        
        event["website"] = URL(string: "https://example.com/events/2")
        #expect(event.attributes["website"] as? String == "https://example.com/events/2")
    }
}
