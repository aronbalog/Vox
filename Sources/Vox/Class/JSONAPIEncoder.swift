import Foundation

enum JSONAPIEncoder {
    /// The JSON data of a request document.
    ///
    /// - Throws: `JSONAPIError.serialization` when the document can't be represented in JSON.
    static func data(of document: [String: Any]) throws(JSONAPIError) -> Data {
        guard JSONSerialization.isValidJSONObject(document),
              let data = try? JSONSerialization.data(withJSONObject: document, options: []) else {
            throw .serialization(reason: "The document can't be represented in JSON.")
        }
        
        return data
    }
}
