import Foundation

/// A links object: the links of a document, resource, relationship or error object.
public struct Links: @unchecked Sendable {
    /// The links by name. Links whose value is `null` are left out.
    public let all: [String: Link]
    
    public subscript(name: String) -> Link? {
        return all[name]
    }
    
    /// The link that generated the document, or that identifies the resource or relationship.
    public var selfLink: Link? {
        return all["self"]
    }
    
    /// The related resource link of a relationship.
    public var related: Link? {
        return all["related"]
    }
    
    /// A link to a description document, such as an OpenAPI or JSON Schema document.
    public var describedby: Link? {
        return all["describedby"]
    }
    
    /// The first page of a paginated collection.
    public var first: Link? {
        return all["first"]
    }
    
    /// The previous page of a paginated collection.
    public var prev: Link? {
        return all["prev"]
    }
    
    /// The next page of a paginated collection.
    public var next: Link? {
        return all["next"]
    }
    
    /// The last page of a paginated collection.
    public var last: Link? {
        return all["last"]
    }
    
    /// A link to details about a particular occurrence of an error.
    public var about: Link? {
        return all["about"]
    }
    
    /// A link identifying the type of an error.
    public var type: Link? {
        return all["type"]
    }
    
    init?(json: Any?) {
        guard let json = json as? [String: Any] else {
            return nil
        }
        
        all = json.compactMapValues(Link.init(json:))
    }
}

/// A link, received as a string or as a link object.
public struct Link: @unchecked Sendable {
    /// The URI-reference of the link target as received, which may be relative.
    public let href: String
    /// The relation type of the link.
    public let rel: String?
    /// The title of the link target.
    public let title: String?
    /// The media type of the link target.
    public let type: String?
    /// The languages of the link target.
    public let hreflang: [String]?
    public let meta: [String: Any]?
    
    private let describedbyLink: [Link]
    
    /// A link to a description document of the link target.
    public var describedby: Link? {
        return describedbyLink.first
    }
    
    /// `href` as a URL, relative when `href` is relative.
    ///
    /// Characters that aren't allowed in URLs, such as the brackets of unencoded `page[number]`
    /// query parameters, are percent-encoded.
    public var url: URL? {
        if let url = URL(string: href) {
            return url
        }
        
        return href.addingPercentEncoding(withAllowedCharacters: Link.allowedCharacters).flatMap(URL.init(string:))
    }
    
    private static let allowedCharacters: CharacterSet = {
        var characters = CharacterSet.urlQueryAllowed
        characters.insert(charactersIn: "#%")
        
        return characters
    }()
    
    init?(json: Any?) {
        switch json {
        case let href as String:
            self.href = href
            rel = nil
            title = nil
            type = nil
            hreflang = nil
            meta = nil
            describedbyLink = []
        case let object as [String: Any]:
            guard let href = object["href"] as? String else {
                return nil
            }
            
            self.href = href
            rel = object["rel"] as? String
            title = object["title"] as? String
            type = object["type"] as? String
            hreflang = (object["hreflang"] as? [String]) ?? (object["hreflang"] as? String).map { [$0] }
            meta = object["meta"] as? [String: Any]
            describedbyLink = Link(json: object["describedby"]).map { [$0] } ?? []
        default:
            return nil
        }
    }
}
