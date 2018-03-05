import Foundation

open class Resource: BaseResource {
    let internalIdentifier = "<Resource_\(UUID().uuidString)>"
    
    open class var resourceType: String {
        fatalError("Must override `static var resourceType: String`")
    }
    
    open class var codingKeys: [String: String] {
        return [:]
    }
    
    private var resourceContext: Context?
    private var resourceObject: NSMutableDictionary?
    weak var context: Context?
    weak var object: NSMutableDictionary?
    
    public var id: String?
    public lazy var type: String = Swift.type(of: self).resourceType
    
    public var meta: NSMutableDictionary? {
        var _meta: NSMutableDictionary?
        
        context?.queue.sync {
            _meta = object?["meta"] as? NSMutableDictionary
        }
        
        return _meta
    }
    
    public var attributes: NSMutableDictionary? {
        var _attributes: NSMutableDictionary?
        
        context?.queue.sync {
            _attributes = object?["attributes"] as? NSMutableDictionary
        }
        
        return _attributes
    }
    
    public var relationships: NSMutableDictionary? {
        var _relationships: NSMutableDictionary?
        
        context?.queue.sync {
            _relationships = object?["relationships"] as? NSMutableDictionary
        }
        
        return _relationships
    }
    
    public required init(context: Context? = nil) {
        super.init()

        if context == nil {
            let _context = Context(dictionary: NSMutableDictionary())
            let _object = NSMutableDictionary()
            self.resourceContext = _context
            self.resourceObject = _object
            self.context = _context
            self.object = _object
        } else {
            self.context = context
        }
    }
    
    open override func value(forKey key: String) -> Any? {
        let key = Swift.type(of: self).codingKeys[key] ?? key
        return context?.value(forKey: key, inResource: self)
    }
    
    open override func setValue(_ value: Any?, forKey key: String) {
        let key = Swift.type(of: self).codingKeys[key] ?? key
        context?.setValue(value, forKey: key, inResource: self)
    }
    
    public func documentDictionary() throws -> [String: Any] {
        let attributes = self.attributes
        let relationships = self.relationships
        
        var dictionary: [String: Any] = [
            "type": self.type
        ]
        
        if let id = id {
            dictionary["id"] = id
        }
        
        if let attributes = attributes,
            attributes.count > 0 {
            dictionary["attributes"] = attributes
        }
        
        if let relationships = relationships,
            relationships.count > 0 {
            dictionary["relationships"] = relationships
        }
        
        return ["data": dictionary]
    }
    
    public func documentData() throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: documentDictionary(), options: [])
        
        return data
    }
    
    func reassignContext(_ context: Context) {
        self.context = context
        self.resourceContext = context
    }
}

extension Resource {
    subscript(key: String) -> Any? {
        get {
            return value(forKey: key)
        }
        set {
            setValue(newValue, forKey: key)
        }
    }
}

extension Array where Element: Resource {
    public func documentDictionary() throws -> [String: Any] {
        let array = try map { (resource) throws -> [String: Any] in
            guard let id = resource.id else {
                throw JSONAPIError.serialization
            }
            
            let attributes = resource.attributes
            let relationships = resource.relationships
            
            var dictionary: [String: Any] = [
                "id": id,
                "type": resource.type
            ]
            
            if let attributes = attributes,
                attributes.count > 0 {
                dictionary["attributes"] = attributes
            }
            
            if let relationships = relationships,
                relationships.count > 0 {
                dictionary["relationships"] = relationships
            }
            
            return dictionary
        }
        
        return ["data": array]
    }
    
    public func documentData() throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: documentDictionary(), options: [])
        
        return data
    }
}
