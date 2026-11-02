import Foundation

/// Provides the paths of a data source's requests.
///
/// Paths can contain the `<type>` and `<id>` placeholders, which are replaced with the resource
/// type and id.
public protocol Router: Sendable {
    func fetch(id: String, type: Resource.Type) -> String
    func fetch(type: Resource.Type) -> String
    func create(resource: Resource) -> String
    func update(resource: Resource) -> String
    func delete(id: String, type: Resource.Type) -> String
    
    /// The path of the relationship `name` of `resource`, for fetching and changing its
    /// linkage, when the relationship has no `self` link. `resource` has an `id`.
    ///
    /// Defaults to the path of the resource followed by `/relationships/<name>`.
    func relationship(_ name: String, of resource: Resource) -> String
    
    /// The path of the resources related to `resource` through the relationship `name`, when
    /// the relationship has no `related` link. `resource` has an `id`.
    ///
    /// Defaults to the path of the resource followed by `/<name>`.
    func related(_ name: String, of resource: Resource) -> String
}

extension Router {
    public func relationship(_ name: String, of resource: Resource) -> String {
        return fetch(id: resource.id ?? "", type: type(of: resource)) + "/relationships/" + name
    }
    
    public func related(_ name: String, of resource: Resource) -> String {
        return fetch(id: resource.id ?? "", type: type(of: resource)) + "/" + name
    }
}
