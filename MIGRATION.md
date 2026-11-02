# Migrating from Vox 1.x to 2.0

Vox 2.0 requires Swift 6.1 and is built around `async`/`await`. Resource definitions keep working as they are. Most changes affect clients, the way requests are sent, and code that reads links or handles errors.

## Requirements and installation

- Vox 2.0 requires Swift 6.1, which comes with Xcode 16.3 and later. Vox builds in the Swift 6 language mode, and apps can still use the Swift 5 mode.
- The minimum deployment target is iOS 13, which was iOS 8. Vox also supports macOS 10.15, tvOS 13, watchOS 6 and Linux.
- Vox is a Swift package with the product `Vox`. The CocoaPods pod is `Vox`, without subspecs: the `Vox/Alamofire` subspec is removed, and Vox no longer depends on Alamofire.
- The sources moved from `Vox/Core` to `Sources/Vox`. Vox no longer contains Objective-C code, an umbrella header or an Xcode project.

## Resources

Resource subclasses and their `@objc dynamic` properties don't change. Classes are now prepared when their first instance is created, instead of at launch. Overriding `resourceType` is optional: a class that doesn't override it has the name of the class as its type, instead of crashing.

### Initialization and contexts

`Context` and `Resource.init(context:)` are removed. Resources are created with `init()`, and documents keep their JSON in a graph of their own.

```swift
// 1.x
let person = Person(context: nil)

// 2.0
let person = Person()
```

`Context.registerClass(_:)` is replaced by `Resource.register()`, which is needed only on platforms without the Objective-C runtime:

```swift
// 1.x
Context.registerClass(Person.self)

// 2.0
Person.register()
```

### Attributes, relationships and type

`attributes` and `relationships` return `[String: Any]` instead of `NSMutableDictionary?`, and they're read-only. Members are changed through properties or the subscript:

```swift
// 1.x
person.attributes?["name"] = "Ann"

// 2.0
person.name = "Ann"
person["name"] = "Ann"
```

`meta` is a `[String: Any]?` instead of an `NSMutableDictionary?`, and it's serialized with the resource. `type` is read-only; for instances of subclasses, it's their `resourceType`.

### Serialization

- Serializing a collection requires each resource to have an `id` or a `lid`. Relationships to resources created in code require the same of the related resources. Both throw `JSONAPIError.serialization(reason:)` otherwise.
- Setting a relationship to `nil` leaves it out of the document. Use `.null()` and `.null` to empty relationships.
- An empty to-many relationship is sent as `"data": []` instead of `"data": null`.
- Values that can't be represented in JSON throw instead of crashing with an Objective-C exception.
- `NSNumber.null` is now NaN. An attribute set to 2147483647 used to be sent as `null`.
- `isNull` is internal.

### Property types

What a property is comes from its declared type, instead of the value it holds:

- An empty array assigned to an attribute stays an attribute.
- A value that doesn't match the declared type reads as `nil` instead of crashing.
- `Date` properties read and write ISO 8601 strings. In 1.x they always read `nil`.

## Documents

### Links

`Links` is a struct of `Link` values, which hold the `href` and the other members of link objects. Documents with link objects or `null` links used to have no links at all.

```swift
// 1.x
let next: URL? = document.links?.next
let current: URL? = document.links?._self

// 2.0
let next: URL? = document.links?.next?.url
let current: URL? = document.links?.selfLink?.url
```

`ErrorObject.links` is a `Links` value instead of a dictionary. Resources and relationships have links too: see `Resource.links` and `Resource.relationship(named:)`.

### Deserialization

- Data that isn't a JSON:API document throws `JSONAPIError.invalidDocument(reason:)` instead of `JSONAPIError.serialization`.
- `Deserializer.Single` throws for an array of resources, and `Deserializer.Collection` throws for a single resource. Before, the data was `nil`.
- Primary data of another class than the type parameter throws, instead of being dropped. Collections that mix types are decoded with `Deserializer.Collection<Resource>`.
- Resources of types without a class are decoded as plain `Resource` instances, instead of being dropped.
- `jsonapi` is decoded. It used to be read from `jsonApi`, so it was always `nil`.
- `meta` and `links` of a document can change. They're those of the last page after `appendNext()`.

## Errors

`JSONAPIError.serialization` has a reason. Patterns without the reason still match:

```swift
// 1.x and 2.0
catch JSONAPIError.serialization { }

// 2.0
catch JSONAPIError.serialization(let reason) { print(reason) }
```

There are two new cases, which exhaustive `switch` statements need to handle:

- `invalidDocument(reason:)` for data that isn't the expected document.
- `unacceptableStatusCode(_:body:)` for responses with a status code outside 200–299 and without error objects.

Deserialization and serialization are declared `throws(JSONAPIError)`. In `do` blocks that only deserialize or serialize, `error` is a `JSONAPIError`, so `catch let error as JSONAPIError` can become `catch`, and a `switch` over `error` can handle every case.

`ErrorObject.Source` has a `header`, and `ErrorObject` accepts numeric `status` and `code` members.

## Clients

The `Client` protocol has a single async method. Clients receive a `ClientRequest` and return a `ClientResponse` with any status code. Vox builds the URL, headers and body, and turns responses into documents and errors.

```swift
// 1.x
final class MyClient: Client {
    func executeRequest(path: String, method: String, queryItems: [URLQueryItem], bodyParameters: [String: Any]?, success: @escaping ClientSuccessBlock, failure: @escaping ClientFailureBlock, userInfo: [String: Any]) {
        // ...
    }
}

// 2.0
struct MyClient: Client {
    let baseURL: URL

    func execute(_ request: ClientRequest) async throws -> ClientResponse {
        guard let url = request.url(relativeTo: baseURL) else {
            throw URLError(.badURL)
        }

        // Send request.method, request.headers and request.body to url.

        return ClientResponse(statusCode: statusCode, headers: headers, data: data)
    }
}
```

- Clients must be `Sendable`, and they no longer have to be classes.
- The body is the encoded document, and the headers include the JSON:API media type.
- `ClientSuccessBlock` and `ClientFailureBlock` are removed.
- User info is a `[String: any Sendable]`.

Many apps don't need a client of their own anymore: `URLSessionClient` sends requests with a `URLSession`, and its adapter can add authentication.

The Alamofire client, `JSONAPIClient.Alamofire`, is removed. Use `URLSessionClient` instead:

```swift
// 1.x
let client = JSONAPIClient.Alamofire(baseURL: baseURL)

// 2.0
let client = URLSessionClient(baseURL: baseURL)
```

Apps that need Alamofire's features, such as interceptors, can implement `Client` with an Alamofire `Session`, as in the client above.

## Requests

### Sending requests

`result()` is async. The callback variant no longer throws, always calls back on the main actor, and passes a non-optional error:

```swift
// 1.x
try dataSource.fetch(id: "1").result({ document in
    DispatchQueue.main.async { /* ... */ }
}, { error in
    // error is an Error?
})

// 2.0
let document = try await dataSource.fetch(id: "1").result()

// or
dataSource.fetch(id: "1").result({ document in
    // On the main actor
}, { error in
    // error is an Error
})
```

The success and failure blocks of data sources are `@MainActor` closures. The failure block is called for every failure, including responses whose body isn't an error document.

### Modifiers return copies

`Request` and `FetchRequest` are structs. Their modifiers return configured copies, so a request has to be configured where it's created, or reassigned:

```swift
// 1.x
let request = dataSource.fetch()
request.include(["author"])

// 2.0
var request = dataSource.fetch()
request = request.include(["author"])
```

The second generic parameter of requests is the output of `result()`, instead of the type of the success block:

```swift
// 1.x
FetchRequest<Article, DataSource<Article>.ResourceCollectionSuccessBlock>

// 2.0
FetchRequest<Article, Document<[Article]>>
```

The typealiases of `DataSource`, such as `FetchableResourceCollectionTypeConfigurable`, refer to the new types. `DataSource.DocumentType` is removed; use `Document`.

### Query parameters

Fetch requests build their query parameters when they're sent:

- `include` accumulates paths without duplicates. Calling it twice used to send two `include` parameters.
- `fields` merges sparse fieldsets by type.
- `sort`, `filter` and `paginate` replace earlier values instead of adding parameters.
- Empty includes and sorts are left out instead of being sent as `include=` and `sort=`.
- The parameters are sent in a fixed order, followed by the items of `queryItems(_:)`.

`Sort` is a struct. Its `_ascending` and `_descending` cases are removed; `.ascending(_:)` and `.descending(_:)` still create sorts. The `Pagination` strategies are structs.

### Paths

- Requests for the collection leave `<id>` out of paths, together with the slash before it. A data source with the path `articles/<id>` fetches the collection at `articles`, instead of `articles/<id>`. Separate data sources for the collection and its resources are no longer needed.
- `create` sends resources to the collection, also when they have a client-generated id.
- `update` requires the resource to have an `id`, and throws `JSONAPIError.serialization(reason:)` before sending anything otherwise.

### Responses

- Responses with a status code outside 200–299 throw the error objects of the response, or `JSONAPIError.unacceptableStatusCode(_:body:)`.
- `create` and `update` return `nil` for responses without content, such as `204 No Content`. Responses without content used to crash.
- Fetches without a response document throw `JSONAPIError.invalidDocument(reason:)`.

### Routers and strategies

`Router`, `FilterStrategy` and `PaginationStrategy` inherit from `Sendable`. Structs without mutable state conform as they are. Classes need to be `final` with immutable stored properties, or `@unchecked Sendable` when they synchronize their state themselves.

`Router` has two new requirements for relationship endpoints, `relationship(_:of:)` and `related(_:of:)`. Their default implementations build the paths from `fetch(id:type:)`.

`DataSource` is a final class and no longer inherits from `NSObject`.

## Pagination

- `first`, `next`, `previous`, `last` and `reload` are `FetchRequest<Element, Document<[Element]>>?`. They follow the whole link, including its query, instead of only its path. They're `nil` when the document has no such link, or when it wasn't fetched by a client, which used to be a fatal error.
- `appendNext()` is async and returns `nil` when there's no next page. The callback variant passes `nil` in that case, instead of never calling back. Its completion block is required; when you don't need it, call `try await document.appendNext()`.
- Resources that are on the document already aren't appended again, and `PaginationData.new` lists only the resources that were appended. Included resources are merged by type and id.
- After appending a page, the document has the links and meta of that page, so the next call fetches the page after it. In 1.x, every call fetched the second page.

```swift
// 1.x
document.appendNext({ pagination in
    // ...
}, { error in
    // ...
})

// 2.0
if let pagination = try await document.appendNext() {
    // ...
}
```

## Concurrency

Vox builds in the Swift 6 language mode. Clients, data sources, requests and documents are `Sendable`. `Resource` isn't, because subclasses can add state of their own. To pass resources between isolation domains, declare subclasses without other mutable state `@unchecked Sendable`:

```swift
final class Article: Resource, @unchecked Sendable {
    // ...
}
```

Callbacks run on the main actor, so `DispatchQueue.main.async` in callbacks can be removed.
