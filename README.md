# Vox

Vox is a Swift implementation of [JSON:API](https://jsonapi.org) 1.1 for iOS, macOS, tvOS, watchOS and Linux. Resources are classes whose properties read and write the JSON of their document, and data sources send JSON:API requests with `async`/`await` or callbacks.

[![CI](https://github.com/aronbalog/Vox/actions/workflows/ci.yml/badge.svg)](https://github.com/aronbalog/Vox/actions/workflows/ci.yml)
[![Coverage](https://aronbalog.github.io/Vox/badges/coverage.svg)](https://github.com/aronbalog/Vox/actions/workflows/ci.yml)
[![CocoaPods](https://img.shields.io/cocoapods/v/Vox.svg)](https://cocoapods.org/pods/Vox)
[![Platforms](https://img.shields.io/cocoapods/p/Vox.svg)](https://cocoapods.org/pods/Vox)

Upgrading from 1.x? Read the [migration guide](MIGRATION.md). Changes are listed in the [changelog](CHANGELOG.md).

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Defining resources](#defining-resources)
- [How resources work](#how-resources-work)
- [Reading documents](#reading-documents)
- [Writing documents](#writing-documents)
- [Networking](#networking)
    - [Clients](#clients)
    - [Data sources](#data-sources)
    - [Fetching](#fetching)
    - [Creating, updating and deleting](#creating-updating-and-deleting)
    - [Headers, query items and user info](#headers-query-items-and-user-info)
    - [Errors](#errors)
    - [Pagination](#pagination)
    - [Relationships](#relationships)
    - [Custom routing](#custom-routing)
- [Concurrency](#concurrency)
- [Linux](#linux)
- [Tests](#tests)
- [Contributing](#contributing)
- [License](#license)

## Features

- Resources with typed attributes and to-one, to-many and polymorphic relationships, which are resolved from `included` when they're read.
- Compound documents, links and link objects, `meta`, `jsonapi`, local identifiers (`lid`) and error objects.
- Requests with `async`/`await`, or with callbacks on the main actor.
- Sparse fieldsets, includes, sorting, filtering, and page-, offset- and cursor-based pagination.
- Relationship endpoints: fetching related resources and linkage, and replacing, adding and removing members.
- A `URLSession` client, or a client of your own.
- The Swift 6 language mode with complete data-race checking.

## Requirements

- Swift 6.1, which comes with Xcode 16.3 and later
- iOS 13, macOS 10.15, tvOS 13, watchOS 6 or Linux

## Installation

### Swift Package Manager

Add the package to the dependencies in `Package.swift`:

```swift
.package(url: "https://github.com/aronbalog/Vox.git", .upToNextMinor(from: "2.0.0"))
```

and the `Vox` product to your target:

```swift
.target(name: "App", dependencies: [
    .product(name: "Vox", package: "Vox")
])
```

In Xcode, choose File > Add Package Dependencies and enter the URL of the repository.

### CocoaPods

```ruby
pod 'Vox', '~> 2.0.0'
```

## Defining resources

A resource is a subclass of `Resource` that declares its JSON:API type in `resourceType`, and its attributes and relationships as `@objc dynamic` properties:

```swift
import Vox

final class Article: Resource {
    override class var resourceType: String { "articles" }

    // Attributes
    @objc dynamic var title: String?
    @objc dynamic var keywords: [String]?
    @objc dynamic var viewCount: NSNumber?
    @objc dynamic var isFeatured: NSNumber?
    @objc dynamic var publishedAt: Date?
    @objc dynamic var coverImage: URL?
    @objc dynamic var extras: [String: Any]?

    // Relationships
    @objc dynamic var author: Person?
    @objc dynamic var comments: [Comment]?
    @objc dynamic var tags: [Tag]?
}

final class Person: Resource {
    override class var resourceType: String { "people" }

    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var favoriteArticle: Article?
}
```

Properties can also be declared with `@Member`, which reads and writes the JSON on every platform, including Linux. `@Member` properties can have Swift types such as `Int`, `Double` and `Bool`, and an initial value:

```swift
final class Comment: Resource {
    override class var resourceType: String { "comments" }

    @Member var body: String?
    @Member var likeCount: Int = 0
    @Member var author: Person?
}
```

- A class that doesn't override `resourceType` has the name of the class as its type. A subclass with the same type as its superclass isn't registered for it, so resources of that type decode as instances of the superclass.
- A property typed as a `Resource` subclass is a to-one relationship, and a property typed as an array of one is a to-many relationship. All other properties are attributes.
- A relationship declared as `Resource` or `[Resource]` can hold resources of any type. Each resource is an instance of the class of its type, so `as? Person` tells them apart.
- Attributes can be strings, numbers, Booleans, dates, URLs, and arrays and dictionaries of JSON values. With `@objc dynamic`, numbers and Booleans are declared as `NSNumber`, because `Int`, `Double` and `Bool` properties can't be backed by the JSON.
- `Date` attributes are ISO 8601 strings in JSON. Date-times can have any offset and fractional seconds, and plain dates are taken as midnight UTC. Dates are sent as UTC date-times.
- `URL` attributes are strings in JSON.
- A value whose JSON type doesn't match the property reads as `nil`, like a missing one. A `@Member` property with an initial value reads that value instead.

Properties named differently than their member are mapped with `codingKeys`:

```swift
override class var codingKeys: [String: String] {
    ["descriptionText": "description"]
}
```

Every resource has an `id`, a `lid`, a `type`, `meta` and `links`, and `attributes` and `relationships` return its JSON. The subscript reads and writes members by property or member name, including members without a property:

```swift
article["subtitle"] = "A JSON:API client"
let subtitle = article["subtitle"] as? String
```

## How resources work

The properties of resources don't store values. Their accessors read and write the JSON of the resource, so a resource is a typed view of its resource object:

```swift
let person = Person()
person.name = "Sherlock Holmes"

person.attributes["name"] // "Sherlock Holmes"
```

The resources of a document share a graph that holds their JSON, and relationships are looked up in the graph when they're read:

- The resources of `included` are created when a relationship is first read.
- Relationships keep working after the document is released.
- A resource object has at most one live instance, so two articles by the same author return the same `Person`.
- Cyclic relationships don't leak.
- A resource from another document can be assigned to a relationship. It replaces the resource with the same type and id.

## Reading documents

`Deserializer.Single` decodes documents whose primary data is a resource, and `Deserializer.Collection` decodes documents whose primary data is an array of resources:

```swift
let document = try Deserializer.Single<Article>().deserialize(data: data)
let article = document.data    // Article?
let author = article?.author   // Person?, from `included`

let collection = try Deserializer.Collection<Article>().deserialize(data: data)
let articles = collection.data // [Article]?
```

A `Document` has these properties:

| Property   | Type               | Contains                                               |
|:-----------|:-------------------|:-------------------------------------------------------|
| `data`     | `DataType?`        | The primary data: a resource or an array of resources  |
| `meta`     | `[String: Any]?`   | The `meta` member                                      |
| `jsonapi`  | `[String: Any]?`   | The `jsonapi` member                                   |
| `links`    | `Links?`           | The `links` member, for example the pagination links   |
| `included` | `[[String: Any]]?` | The included resource objects as JSON                  |

Documents with `"data": null` have no data, and documents with only `meta` are valid. Integer ids are converted to strings.

Deserializers throw `JSONAPIError.API` with the error objects of error documents, and `JSONAPIError.invalidDocument(reason:)` for data that isn't the expected JSON:API document. The reason names the problem, such as "The resource object at included[3] has no type." Primary data of another class is invalid too, and so is an array when a single resource is expected. Deserializers are declared `throws(JSONAPIError)`, so `error` is a `JSONAPIError` in their `catch` clauses.

```swift
do {
    let document = try Deserializer.Single<Article>().deserialize(data: data)
    // ...
} catch JSONAPIError.API(let errors) {
    for error in errors {
        print(error.status ?? "", error.title ?? "", error.detail ?? "", error.source?.pointer ?? "")
    }
} catch JSONAPIError.invalidDocument(let reason) {
    print(reason)
}
```

### Mixed and unknown types

Collections that mix types are decoded with `Resource` as the type parameter:

```swift
let document = try Deserializer.Collection<Resource>().deserialize(data: data)

for resource in document.data ?? [] {
    switch resource {
    case let article as Article:
        print(article.title ?? "")
    case let person as Person:
        print(person.name ?? "")
    default:
        print(resource.type, resource.attributes)
    }
}
```

Resources of types without a class are decoded as plain `Resource` instances, so their JSON stays readable.

### Links and meta

`Links` maps names to `Link` values, which are decoded from strings and link objects alike:

```swift
document.links?.next?.href      // String
document.links?.next?.url       // URL, with characters such as brackets percent-encoded
article.links?.selfLink?.meta   // [String: Any]?

let relationship = article.relationship(named: "author")
relationship?.links?.related?.url
relationship?.meta
relationship?.hasData           // whether the document contains the linkage
```

`relationship(named:)` takes the name of a property or of a relationship member.

## Writing documents

```swift
let person = Person()
person.id = "1"
person.name = "John Doe"
person.age = .null
person.favoriteArticle = .null()

let data = try person.documentData()       // Data
let json = try person.documentDictionary() // [String: Any]
```

```json
{
  "data": {
    "type": "people",
    "id": "1",
    "attributes": {
      "name": "John Doe",
      "age": null
    },
    "relationships": {
      "favoriteArticle": {
        "data": null
      }
    }
  }
}
```

Collections are serialized the same way. Each of their resources needs an `id` or a `lid`:

```swift
let data = try [person1, person2].documentData()
```

Serialization throws `JSONAPIError.serialization(reason:)` when the resource can't be represented: for example, when an attribute holds a value that isn't JSON, such as `Data`, or when a related resource has neither an `id` nor a `lid`. It also throws for attributes and relationships named `type` or `id`, and for an attribute and a relationship with the same name, which JSON:API doesn't allow. Like deserialization, it's declared `throws(JSONAPIError)`.

### Nullability

- Setting a property to `.null` sends `null`. To-one relationships use `.null()`, which sends `"data": null`, and to-many relationships use `.null`, which sends `"data": []`.
- Setting a property to `nil` leaves the member out.

### Local identifiers

A resource created on the client can have a local identifier, so that other resources can refer to it before the server assigns an id. It's sent as `{ "type": "people", "lid": "new-author" }`:

```swift
let author = Person()
author.lid = "new-author"
article.author = author
```

Once the resource has an `id`, the `id` is sent instead of the `lid`. In received documents, resource identifiers with a `lid` resolve to the resource with that `lid`.

## Networking

### Clients

A client sends the requests of data sources. Vox comes with one, which sends requests with a `URLSession`, the shared one by default:

```swift
let baseURL = URL(string: "https://example.com/api/")!

let client = URLSessionClient(baseURL: baseURL)
```

`JSONAPIClient.URLSession` refers to the same client. The paths of data sources are appended to the base URL, and the links of documents are resolved against it. Cancelling the task that awaits a request cancels the request.

`URLSessionClient` takes an adapter, which can change requests before they're sent:

```swift
let client = URLSessionClient(baseURL: baseURL) { request in
    var request = request
    request.setValue("Bearer \(try await tokenStore.token())", forHTTPHeaderField: "Authorization")
    return request
}
```

Other networking libraries can be used through the `Client` protocol. Clients only transmit: Vox builds the requests and turns the responses into documents and errors, so clients return responses with any status code.

```swift
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

### Data sources

A data source sends the requests for one type of resource:

```swift
let articles = DataSource<Article>(strategy: .path("articles/<id>"), client: client)
```

In paths, `<type>` is replaced with the resource type and `<id>` with the id. Requests for the collection leave `<id>` out, together with the slash before it, so this data source fetches `articles` and `articles/1`, creates resources at `articles`, and updates and deletes them at `articles/1`. URLs that don't follow this pattern are built by a [router](#custom-routing).

Requests are sent with `result()`:

```swift
let document = try await articles.fetch(id: "1").result()
let article = document.data // Article?
```

or with callbacks, which are called on the main actor:

```swift
articles.fetch(id: "1").result({ document in
    print(document.data?.title ?? "")
}, { error in
    print(error)
})
```

Requests are immutable values. Their modifiers return configured copies, so requests can be reused, stored and passed between tasks.

### Fetching

```swift
let document = try await articles
    .fetch()
    .include(["author", "comments.author"])
    .fields(["articles": ["title", "author"], "people": ["name"]])
    .filter(Filter(["keyword": "swift"]))
    .sort([.descending("publishedAt"), .ascending("title")])
    .paginate(Pagination.PageBased(number: 1, size: 20))
    .result()

let list = document.data // [Article]?
```

- `include` adds paths, leaving out the ones included already.
- `fields` merges sparse fieldsets by type. An empty list requests no fields of the type.
- `filter`, `sort` and `paginate` replace earlier values.
- `Filter` sends `filter[field]=value` parameters, as the JSON:API recommendations suggest. Other filters implement `FilterStrategy`.
- The parameters are sent in a fixed order, and empty ones are left out.

The pagination strategies are `Pagination.PageBased(number:size:)`, `Pagination.OffsetBased(offset:limit:)` and `Pagination.CursorBased(cursor:)`. Others implement `PaginationStrategy`:

```swift
struct AfterCursor: PaginationStrategy {
    let cursor: String

    func paginationURLQueryItems() -> [URLQueryItem] {
        [URLQueryItem(name: "page[after]", value: cursor)]
    }
}
```

### Creating, updating and deleting

```swift
let draft = Article()
draft.title = "Hello, world"

// POST articles
let created = try await articles.create(draft).result()

// PATCH articles/1
let changes = Article()
changes.id = "1"
changes.title = "Hello, JSON:API"
let updated = try await articles.update(changes).result()

// DELETE articles/1
try await articles.delete(id: "1").result()
```

- `create` and `update` return `nil` when the server responds without content, such as with `204 No Content`.
- `create` sends resources to the collection, also when they have a client-generated id.
- `update` sends every member the resource has, so a new resource with the id sends only the members that change. The resource needs an `id`.

### Headers, query items and user info

```swift
let document = try await articles
    .fetch(id: "1")
    .headers(["Accept-Language": "en"])
    .queryItems([URLQueryItem(name: "preview", value: "true")])
    .userInfo(["requiresAuthentication": true])
    .result()
```

Every request sends `Accept: application/vnd.api+json`, and requests with a body send the same `Content-Type`. Headers with the same name replace them, compared case-insensitively, for example to request a JSON:API extension. Query items are sent after the JSON:API parameters. User info is passed to the client with the request.

### Errors

Requests throw these errors:

| Error | Thrown when |
|:------|:------------|
| `JSONAPIError.API(errors)` | The server responded with error objects. |
| `JSONAPIError.unacceptableStatusCode(statusCode, body:)` | The status code is outside 200–299 and the response has no error objects. |
| `JSONAPIError.invalidDocument(reason:)` | The response isn't the expected document. |
| `JSONAPIError.serialization(reason:)` | The request document or URL couldn't be built. Nothing was sent. |
| The errors of the client | The request failed, for example with a `URLError`. |

```swift
do {
    let document = try await articles.fetch(id: "1").result()
    // ...
} catch JSONAPIError.API(let errors) {
    print(errors.compactMap(\.detail))
} catch JSONAPIError.unacceptableStatusCode(let statusCode, _) {
    print("Status code", statusCode)
}
```

### Pagination

Collection documents have requests for their pagination links. A request is `nil` when the document has no such link:

```swift
let page = try await articles.fetch().paginate(Pagination.PageBased(number: 1, size: 20)).result()

let nextPage = try await page.next?.result()
let previousPage = try await page.previous?.result()
// page.first, page.last and page.reload work the same way.
```

`appendNext()` fetches the next page and appends it to the document. It returns `nil` when there's no next page:

```swift
if let pagination = try await page.appendNext() {
    pagination.old // The resources before
    pagination.new // The resources that were appended
    pagination.all // All resources, which are now the document's data
}
```

- A resource the document contains already isn't appended again. It shows the values of the new page and stays the same instance.
- Included resources are merged by type and id.
- The document takes the links and meta of the appended page, so the next call continues after it.
- A failed page leaves the document unchanged.

The callback variant passes `nil` when there's no next page:

```swift
page.appendNext({ pagination in
    // ...
}, { error in
    // ...
})
```

Page requests need the client the document was fetched with, so documents decoded with a deserializer have none.

### Relationships

JSON:API defines endpoints for the related resources of a relationship and for the relationship itself. Data sources create requests for both:

```swift
// GET articles/1/author
let author = try await articles.fetchRelated("author", of: article, as: Person.self).result().data

// GET articles/1/comments, which can be sorted, filtered and paginated
let comments = try await articles
    .fetchRelated("comments", of: article, as: [Comment].self)
    .sort([.descending("createdAt")])
    .result()

// GET articles/1/relationships/tags
let linkage = try await articles.fetchRelationship("tags", of: article, as: [Tag].self).result()

// PATCH articles/1/relationships/author
try await articles.updateRelationship("author", of: article, to: person).result()
try await articles.updateRelationship("author", of: article, to: nil).result()

// PATCH, POST and DELETE articles/1/relationships/tags
try await articles.updateRelationship("tags", of: article, to: [swift, ios]).result()
try await articles.addToRelationship("tags", of: article, [concurrency]).result()
try await articles.removeFromRelationship("tags", of: article, [ios]).result()
```

- The requests follow the `related` and `self` links of the relationship. Without links, the path is the path of the resource followed by `/<relationship>` or `/relationships/<relationship>`.
- Relationships are named by property or by member name.
- Related resources are referred to by `id`, or else by `lid`.
- Fetching the linkage returns resources with a type and id, unless the server includes them.

### Custom routing

A router builds the paths of a data source:

```swift
struct APIRouter: Router {
    func fetch(id: String, type: Resource.Type) -> String {
        "v2/\(type.resourceType)/\(id)"
    }

    func fetch(type: Resource.Type) -> String {
        "v2/\(type.resourceType)"
    }

    func create(resource: Resource) -> String {
        "v2/\(resource.type)"
    }

    func update(resource: Resource) -> String {
        "v2/\(resource.type)/\(resource.id ?? "")"
    }

    func delete(id: String, type: Resource.Type) -> String {
        "v2/\(type.resourceType)/\(id)"
    }
}

let articles = DataSource<Article>(strategy: .router(APIRouter()), client: client)
```

Paths of routers can contain `<type>` and `<id>` too. The paths of relationship endpoints come from `relationship(_:of:)` and `related(_:of:)`, which append `/relationships/<name>` and `/<name>` to `fetch(id:type:)` unless the router implements them.

## Concurrency

Vox builds in the Swift 6 language mode, with complete data-race checking.

- Clients, data sources, requests and documents are `Sendable`, so they can be used from any task or actor.
- Callbacks are called on the main actor.
- `Resource` isn't `Sendable`, because subclasses can add state of their own. Access to the JSON of resources is synchronized, so a subclass without other mutable state can be declared `@unchecked Sendable` to pass its instances between isolation domains:

```swift
final class Article: Resource, @unchecked Sendable {
    // ...
}
```

## Linux

Vox builds on Linux, including `URLSessionClient`. Without the Objective-C runtime, two things work differently:

- There are no `@objc dynamic` properties, so properties are declared with `@Member`, which reads and writes the JSON on every platform: `article.title = "Dune"`. A plain stored property only declares the member's type, and is read and written with the subscript: `article["title"] as? String`.
- Classes aren't found by scanning the process. A class is registered when its first instance is created, and when it is the resource type of a data source or a deserializer. The classes of related and included resources still need to be registered before documents containing them are decoded, unless an instance of the class was created first:

```swift
Person.register()
Comment.register()
```

## Tests

```sh
swift test
```

The tests use Swift Testing, and the performance tests use XCTest. Xcode runs them with the `Vox-Package` scheme, which also covers the Apple platforms:

```sh
xcodebuild test -scheme Vox-Package -destination 'platform=iOS Simulator,name=iPhone 16'
```

The tests cover all of the library code that's built on Linux, and the Linux job of the [CI workflow](.github/workflows/ci.yml) fails when a change leaves some of it uncovered. Its steps show how to measure the coverage.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change, and please update the tests as appropriate.

## License

Vox is available under the MIT license. See [LICENSE.md](LICENSE.md).
