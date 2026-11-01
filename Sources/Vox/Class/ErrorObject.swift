import Foundation

/// An error object of a JSON:API document.
final public class ErrorObject {
    /// The part of the request document or request that caused the error.
    final public class Source {
        /// A JSON Pointer to the value in the request document that caused the error.
        public let pointer: String?
        /// The URI query parameter that caused the error.
        public let parameter: String?
        /// The request header that caused the error.
        public let header: String?
        
        init(pointer: String?, parameter: String?, header: String?) {
            self.pointer = pointer
            self.parameter = parameter
            self.header = header
        }
    }
    
    public let id: String?
    /// The `about` and `type` links of the error.
    public let links: Links?
    /// The HTTP status code as a string.
    public let status: String?
    public let code: String?
    public let title: String?
    public let detail: String?
    public let source: Source?
    public let meta: [String: Any]?
    
    init(dictionary: [String: Any]) {
        id = ErrorObject.string(dictionary["id"])
        links = Links(json: dictionary["links"])
        status = ErrorObject.string(dictionary["status"])
        code = ErrorObject.string(dictionary["code"])
        title = dictionary["title"] as? String
        detail = dictionary["detail"] as? String
        
        let source: Source? = {
            guard let source = dictionary["source"] as? [String: Any] else {
                return nil
            }
            
            return Source(
                pointer: source["pointer"] as? String,
                parameter: source["parameter"] as? String,
                header: source["header"] as? String
            )
        }()
        self.source = source
        
        meta = dictionary["meta"] as? [String: Any]
    }
    
    /// A string member, which servers sometimes send as a number.
    private static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as Int:
            return String(number)
        default:
            return nil
        }
    }
}
