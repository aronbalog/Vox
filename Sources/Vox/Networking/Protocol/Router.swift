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
}
