# Changelog

The notable changes of each release. Vox follows [Semantic Versioning](https://semver.org).

## 2.0.0 (unreleased)

A major release, which requires Swift 6. The [migration guide](MIGRATION.md) describes the breaking changes.

### Added

- Swift Package Manager support, with the products `Vox` and `VoxAlamofire`.
- Support for macOS 10.15, tvOS 13, watchOS 6 and Linux.
- The Swift 6 language mode, with complete data-race checking. Clients, data sources, requests and documents are `Sendable`.
- `async` variants of `result()` and `appendNext()`.
- `URLSessionClient`, a client that sends requests with a `URLSession`, with an adapter that can change requests before they're sent.
- Relationship endpoints: `fetchRelated(_:of:as:)`, `fetchRelationship(_:of:as:)`, `updateRelationship(_:of:to:)`, `addToRelationship(_:of:_:)` and `removeFromRelationship(_:of:_:)`, and the router requirements `relationship(_:of:)` and `related(_:of:)`, with default implementations.
- Link objects. `Link` has the `href`, `rel`, `title`, `type`, `hreflang`, `describedby` and `meta` of a link, and `Links` has accessors for the pagination, `related`, `describedby`, `about` and `type` links.
- The links of resources, `Resource.links`, and the links and meta of relationships, `Resource.relationship(named:)`.
- Local identifiers (`lid`) of JSON:API 1.1.
- `Date` and `URL` attributes.
- `Filter`, which sends `filter[field]=value` parameters.
- The JSON:API `Accept` and `Content-Type` headers, and `headers(_:)` for custom headers.
- `JSONAPIError.invalidDocument(reason:)`, `JSONAPIError.unacceptableStatusCode(_:body:)`, and the reason of `JSONAPIError.serialization`.
- `Resource.register()` and the public member subscript, for platforms without the Objective-C runtime.
- The `meta` of resources is serialized.
- `ErrorObject.Source.header`.
- Continuous integration with GitHub Actions on macOS, Linux, iOS, tvOS and watchOS, and CocoaPods linting.

### Changed

- The `Client` protocol has a single async method, `execute(_:)`, which receives a `ClientRequest` and returns a `ClientResponse`.
- Requests are immutable structs. Their modifiers return copies.
- Callbacks are called on the main actor, and the callback variant of `result` no longer throws.
- Responses outside 200–299 throw, and `create` and `update` return `nil` for responses without content.
- The Alamofire client requires Alamofire 5. It sends requests through a `Session` and an optional `RequestInterceptor`, and it's named `AlamofireClient`.
- Resources keep their JSON in a graph. Relationships work after their document is released, cyclic relationships don't leak, a resource object has at most one live instance, and resources can be assigned across documents.
- Property kinds come from the declared types of properties, instead of their values.
- `attributes` and `relationships` return non-optional dictionaries, and `type` is read-only.
- Resource classes are prepared when they're first used, instead of at launch.
- `resourceType` is the name of the class when the class doesn't override it, instead of crashing. A subclass with the same type as its superclass isn't registered for it.
- Fetch requests build their query parameters once, in a fixed order, without duplicates.
- Appending pages skips the resources a document contains already, which take the newer values, and merges included resources. The document takes the links and meta of the appended page.
- Requests for the collection leave `<id>` out of paths, and `create` always sends resources to the collection.
- `update` requires the resource to have an `id`.
- Invalid documents throw `JSONAPIError.invalidDocument(reason:)` with a description of the problem. Primary data of an unexpected shape or class throws.
- Deserialization and serialization are declared `throws(JSONAPIError)`, and `makeURLRequest(for:)` of the clients `throws(URLError)`.
- Resources of types without a class decode as plain `Resource` instances.
- `Sort` is a struct, and the `Pagination` strategies are structs.
- The minimum deployment target is iOS 13.
- The tests use Swift Testing instead of Quick and Nimble.

### Fixed

- `appendNext` fetched the second page on every call, appended resources the document already contained, and included resources twice.
- Page requests dropped the query of links, and crashed when the document had no client.
- One link object, a `null` link or an unencoded bracket in a link made a document's `links` `nil`.
- The `jsonapi` member was always `nil`.
- Responses without content crashed, and some failed requests never called the failure block.
- The Alamofire client rejected error responses and responses without content, and dropped repeated query items.
- Values that can't be represented in JSON crashed with an Objective-C exception.
- An attribute with the value 2147483647 was sent as `null`.
- An empty array assigned to an attribute became a relationship, an empty to-many relationship was sent as `null`, setting a relationship to `nil` didn't remove it, and linkage with meta crashed.
- Values of an unexpected type crashed.
- `Date` attributes read `nil` and failed serialization.
- A resource contained more than once in a document lost the later occurrences.
- Integer ids and resource objects without an id weren't decoded.
- Repeated `include`, `sort`, `filter` and `paginate` calls repeated their parameters, and empty includes and sorts were sent.
- Abstract resource classes crashed at launch, properties with custom getter names were mapped to the wrong member, and properties of primitive types got incompatible accessors.
- Nested synchronization could deadlock.

### Removed

- `Context` and `Resource.init(context:)`.
- The callback-based `Client` requirement, `ClientSuccessBlock` and `ClientFailureBlock`.
- `Links._self`, which is now `selfLink`.
- The underscored cases of `Sort`.
- `DataSource.DocumentType`.
- The Objective-C sources, the umbrella header, the Xcode project and the playground.

## 1.2.3 and earlier

See the [tags on GitHub](https://github.com/aronbalog/Vox/tags).
