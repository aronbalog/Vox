# Vox

Vox is a Swift JSONAPI standard implementation.

[![Build Status](https://travis-ci.org/aronbalog/Vox.svg?branch=master)](https://travis-ci.org/aronbalog/Vox)
[![codecov](https://codecov.io/gh/aronbalog/Vox/branch/master/graph/badge.svg)](https://codecov.io/gh/aronbalog/Vox)
[![Platform](https://img.shields.io/cocoapods/p/Vox.svg?style=flat)](https://github.com/aronbalog/Vox)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Vox.svg)](https://img.shields.io/cocoapods/v/Vox.svg)

- 🎩 [The magic behind](#the-magic-behind)
- 💻 [Installation](#motivation-)
- 🚀 [Usage](#getting-started-)
    - [Defining resource](#defining-resource)
    - [Serializing](#serializing)
        - [Single resource](#single-resource)
        - [Alamofire plugin](#alamofire-plugin)
        - [Resource collection](#resource-collection)
        - [Nullability](#nullability)
    - [Deserializing](#deserializing)
        - [Single resource](#single-resource)
        - [Resource collection](#resource-collection)
    - [Networking](#networking)
        - [Client protocol](#client-protocol)
        - [Alamofire client plugin](#alamofire-client-plugin)
        - [Fetching single resource](#fetching-single-resource)
        - [Fetching resource collection](#fetching-resource-collection)
        - [Creating resource](#creating-resource)
        - [Updating resource](#updating-resource)
        - [Deleting resource](#deleting-resource)
        - [Pagination](#pagination)
            - [Pagination on initial request](#pagination-on-initial-request)
                - [Custom pagination strategy](#custom-pagination-strategy)
                - [Page-based pagination strategy](#page-based-pagination-strategy)
                - [Offset-based pagination strategy](#offset-based-pagination-strategy)
                - [Cursor-based pagination strategy](#cursor-based-pagination-strategy)
            - [Appending next page to current document](#appending-next-page-to-current-document)
            - [Fetching next document page](#fetching-next-document-page)
            - [Fetching previous document page](#fetching-previous-document-page)
            - [Fetching first document page](#fetching-first-document-page)
            - [Fetching last document page](#fetching-last-document-page)
            - [Reloading current document page](#reloading-current-document-page)
        - [Custom routing](#custom-routing)
- ✅ [Tests](#tests)
- [Contributing](#contributing)
- [License](#license)

## The magic behind

Vox combines Swift with Objective-C dynamism and C selectors. During serialization and deserialization JSON is not mapped to resource object(s). Instead, it uses [Marshalling](https://en.wikipedia.org/wiki/Marshalling_(computer_science)) and [Unmarshalling](https://en.wikipedia.org/wiki/Unmarshalling) techniques to deal with direct memory access and performance challenges. Proxy (surrogate) design pattern gives us an opportunity to manipulate JSON's value directly through class properties and vice versa.

```swift
import Vox

class Person: Resource {
    @objc dynamic var name: String?
}

let person = Person()
    person.name = "Sherlock Holmes"
    
    print(person.attributes?["name"]) // -> "Sherlock Holmes"
```

Let's explain what's going on under the hood!

- Setting the person's name won't assign the value to `Person` object. Instead it will directly mutate the JSON behind (the one received from server).

- Getting the property will actually resolve the value in JSON (it points to its actual memory address).

- When values in resource's `attributes` or `relationship` dictionaries are directly changed, getting the property value will resolve to the one changed in JSON.

Every attribute or relationship (`Resource` subclass property) must have `@objc dynamic` prefix to be able to do so.

> Think about your `Resource` classes as strong typed interfaces to a JSON object.


This opens up the possibility to easily handle the cases with:

- I/O performance
- polymorphic relationships
- relationships with circular references
- lazy loading resources from includes list

## Installation

### Requirements
* Xcode 9
* Cocoapods

Basic

```ruby
pod 'Vox'
```

With [Alamofire](https://github.com/Alamofire/Alamofire) plugin

```ruby
pod 'Vox/Alamofire'
```

## Usage

### Defining resource

```swift
import Vox

class Article: Resource {

    /*--------------- Attributes ---------------*/
    
    @objc dynamic
    var title: String?
    
    @objc dynamic
    var descriptionText: String?

    @objc dynamic
    var keywords: [String]?
    
    @objc dynamic
    var viewsCount: NSNumber?
    
    @objc dynamic
    var isFeatured: NSNumber?
    
    @objc dynamic
    var customObject: [String: Any]?
    
    /*------------- Relationships -------------*/
        
    @objc dynamic
    var authors: [Person]?

    @objc dynamic
    var editor: Person?

    /*------------- Resource type -------------*/

    // resource type must be defined
    override class var resourceType: String {
        return "articles"
    }

    /*------------- Custom coding -------------*/

    override class var codingKeys: [String : String] {
        return [
            "descriptionText": "description"
        ]
    }
}
```

### Serializing

#### Single resource

```swift
import Vox
            
let person = Person()
    person.name = "John Doe"
    person.age = .null
    person.gender = "male"
    person.favoriteArticle = .null()
            
let json: [String: Any] = try! person.documentDictionary()

// or if `Data` is needed
let data: Data = try! person.documentData()
```

Previous example will resolve to following JSON:

```json
{
  "data": {
    "attributes": {
      "name": "John Doe",
      "age": null,
      "gender": "male"
    },
    "type": "persons",
    "id": "id-1",
    "relationships": {
      "favoriteArticle": {
        "data": null
      }
    }
  }
}
```
*In this example favorite article is unassigned from person. To do so, use `.null()` on resource properties and `.null` on all other properties.*

#### Resource collection

```swift
import Vox

let article = Article()
    article.id = "article-identifier"

let person1 = Person()
    person1.id = "id-1"
    person1.name = "John Doe"
    person1.age = .null
    person1.gender = "male"
    person1.favoriteArticle = article

let person2 = Person()
    person2.id = "id-2"
    person2.name = "Mr. Nobody"
    person2.age = 99
    person2.gender = .null
    person2.favoriteArticle = .null()


let json: [String: Any] = try! [person1, person2].documentDictionary()

// or if `Data` is needed
let data: Data = try! [person1, person2].documentData()
```

Previous example will resolve to following JSON:

```json
{
  "data": [
    {
      "attributes": {
        "name": "John Doe",
        "age": null,
        "gender": "male"
      },
      "type": "persons",
      "id": "id-1",
      "relationships": {
        "favoriteArticle": {
          "data": {
            "id": "article-identifier",
            "type": "articles"
          }
        }
      }
    },
    {
      "attributes": {
        "name": "Mr. Nobody",
        "age": 99,
        "gender": null
      },
      "type": "persons",
      "id": "id-2",
      "relationships": {
        "favoriteArticle": {
          "data": null
        }
      }
    }
  ]
}
```

#### Nullability

Use `.null()` on `Resource` type properties or `.null` on any other type properties.

- Setting property value to `.null` (or `.null()`) will result in JSON value being set to `null`
- Setting property value to `nil` will remove value from JSON

### Deserializing

#### Single resource

```swift
import Vox

let data: Data // -> provide data received from JSONAPI server

let deserializer = Deserializer.Single<Article>()

do {
    let document = try deserializer.deserialize(data: self.data)
    
    // `document.data` is an Article object
    
} catch JSONAPIError.API(let errors) {
    // API response is valid JSONAPI error document
    errors.forEach { error in
        print(error.title, error.detail)
    }
} catch JSONAPIError.serialization {
    print("Given data is not valid JSONAPI document")
} catch {
    print("Something went wrong. Maybe `data` does not contain valid JSON?")
}
```

#### Resource collection

```swift
import Vox

let data: Data // -> provide data received from JSONAPI server

let deserializer = Deserializer.Collection<Article>()

let document = try! deserializer.deserialize(data: self.data)

// `document.data` is an [Article] object
```

#### Description

Provided data must be `Data` object containing valid JSONAPI document or error. If this preconditions are not met, `JSONAPIError.serialization` error will be thrown.

Deserializer can also be declared without generic parameter but in that case the resource's `data` property may need an enforced casting on your side so using generics is recommended.

`Document<DataType: Any>` has following properties:

| Property        | Type              | Description                               |
|:--------------- |:------------------|:------------------------------------------|
| `data`          | `DataType`        | Contains the single resource or resource collection
| `meta`          | `[String: Any]`   | `meta` dictionary
| `jsonapi`       | `[String: Any]`   | `jsonApi` dictionary
| `links`         | `Links`           | `Links` object, e.g. can contain pagination data
| `included`      | `[[String: Any]]` | `included` array of dictionaries

### Networking

`<id>` and `<type>` annotations can be used in path strings. If possible, they'll get replaced with adequate values.

#### Client protocol

Implement following method from `Client` protocol:

```swift
func executeRequest(path: String,
                  method: String,
              queryItems: [URLQueryItem],
          bodyParameters: [String : Any]?,
                 success: @escaping ClientSuccessBlock,
                 failure: @escaping ClientFailureBlock,
                userInfo: [String: Any])
```

where

- `ClientSuccessBlock` = `(HTTPURLResponse?, Data?) -> Void`
- `ClientFailureBlock` = `(Error?, Data?) -> Void`

Note:

`userInfo` contains custom data you can pass to the client to do some custom logic: e.g. add some extra headers, add encryption etc.

#### Alamofire client plugin

If custom networking is not required, there is a plugin which wraps [Alamofire](https://github.com/Alamofire/Alamofire) and provides networking client in accordance  with JSON:API specification.

> Alamofire is Elegant HTTP Networking in Swift

Example:

```swift
let baseURL = URL(string: "http://demo7377577.mockable.io")!
let client = JSONAPIClient.Alamofire(baseURL: baseURL)
let dataSource = DataSource<Article>(strategy: .path("vox/articles"), client: client)

dataSource
    .fetch()
    ...
```

##### Installation

```ruby
pod 'Vox/Alamofire'
```

#### Fetching single resource

```swift
let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>/<id>"), client: client)

dataSource
    .fetch(id:"1")
    .include([
        "favoriteArticle"
    ])
    .result({ (document: Document<Person>) in
        let person = document?.data // ➜ `person` is `Person?` type
    }) { (error) in
        if let error = error as? JSONAPIError {
            switch error {
            case .API(let errors):
                ()
            default:
                ()
            }
        }
    }
```

#### Fetching resource collection

```swift
let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>"), client: client)

dataSource(url: url)
    .fetch()
    .include([
        "favoriteArticle"
    ])
    .result({ (document: Document<[Person]>) in
        let persons = document.data // ➜ `persons` is `[Person]?` type
    }) { (error) in
        
    }
```

#### Creating resource

```swift
let person = Person()
    person.id = "1"
    person.name = "Name"
    person.age = 40
    person.gender = "female"
            
let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>"), client: client)

dataSource
    .create(person)
    .result({ (document: Document<Person>?) in
        let person = document?.data // ➜ `person` is `Person?` type
    }) { (error) in
        
    }
```

#### Updating resource

```swift
let person = Person()
    person.id = "1"
    person.age = 41
    person.gender = .null
            
let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>/<id>"), client: client)

dataSource
    .update(resource: person)
    .result({ (document: Document<Person>?) in
        let person = document?.data // ➜ `person` is `Person?` type
    }) { (error) in
        
    }
```

#### Deleting resource

```swift
let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>/<id>"), client: client)
            
dataSource
    .delete(id: "1")
    .result({
            
    }) { (error) in
        
    }
```

#### Pagination

##### Pagination on initial request

###### Custom pagination strategy

```swift
let paginationStrategy: PaginationStrategy // -> your object conforming `PaginationStrategy` protocol

let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>"), client: client)

dataSource
    .fetch()
    .paginate(paginationStrategy)
    .result({ (document) in
        
    }, { (error) in
        
    })
```

###### Page-based pagination strategy

```swift
let paginationStrategy = Pagination.PageBased(number: 1, size: 10)

let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>"), client: client)

dataSource
    .fetch()
    .paginate(paginationStrategy)
    .result({ (document) in
        
    }, { (error) in
        
    })
```

###### Offset-based pagination strategy

```swift
let paginationStrategy = Pagination.OffsetBased(offset: 10, limit: 10)

let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>"), client: client)

dataSource
    .fetch()
    .paginate(paginationStrategy)
    .result({ (document) in
        
    }, { (error) in
        
    })
```

###### Cursor-based pagination strategy

```swift
let paginationStrategy = Pagination.CursorBased(cursor: "cursor")

let dataSource = DataSource<Person>(strategy: .path("custom-path/<type>"), client: client)

dataSource
    .fetch()
    .paginate(paginationStrategy)
    .result({ (document) in
        
    }, { (error) in
        
    })
```

##### Appending next page to current document

```swift
document.appendNext({ (data) in
    // data.old -> Resource values before pagination
    // data.new -> Resource values from pagination
    // data.all -> Resource values after pagination
    
    // document.data === data.all -> true
}, { (error) in

})
```

##### Fetching next document page

```swift
document.next?.result({ (nextDocument) in
    // `nextDocument` is same type as `document`
}, { (error) in
    
})
```

##### Fetching previous document page

```swift
document.previous?.result({ (previousDocument) in
    // `previousDocument` is same type as `document`
}, { (error) in
    
})
```

##### Fetching first document page

```swift
document.first?.result({ (firstDocument) in
    // `firstDocument` is same type as `document`
}, { (error) in
    
})
```

##### Fetching last document page

```swift
document.last?.result({ (lastDocument) in
    // `lastDocument` is same type as `document`
}, { (error) in
    
})
```

##### Reloading current document page

```swift
document.reload?.result({ (reloadedDocument) in
    // `reloadedDocument` is same type as `document`
}, { (error) in
    
})
```

#### Custom routing

Generating URL for resources can be automated.

Make a new object conforming `Router`. Simple example:

```swift
class ResourceRouter: Router {
    func fetch(id: String, type: Resource.Type) -> String {
        let type = type.resourceType
        
        return type + "/" + id // or "<type>/<id>"
    }
    
    func fetch(type: Resource.Type) -> String {
        return type.resourceType // or "<type>"
    }
    
    func create(resource: Resource) -> String {
        return resource.type // or "<type>"
    }
    
    func update(resource: Resource) -> String {
        let type = type.resourceType
        
        return type + "/" + id // or "<type>/<id>"
    }
    
    func delete(id: String, type: Resource.Type) -> String {
        let type = type.resourceType
        
        return type + "/" + id // or "<type>/<id>"
    }
}
```

Then you would use:

```swift
let router = ResourceRouter()

let dataSource = DataSource<Person>(strategy: .router(router), client: client)

dataSource
    .fetch()
    ...
```

## Tests

- [x] DataSource with router and client when creating resource invokes execute request on client
- [x] DataSource with router and client when creating resource invokes correct method on router
- [x] DataSource with router and client when creating resource passes correct parameters to router
- [x] DataSource with router and client when creating resource client receives correct data from router for execution
- [x] DataSource with router and client when fetching single resource invokes execute request on client
- [x] DataSource with router and client when fetching single resource invokes correct method on router
- [x] DataSource with router and client when fetching single resource passes correct parameters to router
- [x] DataSource with router and client when fetching single resource client receives correct data from router for execution
- [x] DataSource with router and client when fetching resource collection invokes execute request on client
- [x] DataSource with router and client when fetching resource collection invokes correct method on router
- [x] DataSource with router and client when fetching resource collection passes correct parameters to router
- [x] DataSource with router and client when fetching resource collection client receives correct data from router for execution
- [x] DataSource with router and client when updating resource invokes execute request on client
- [x] DataSource with router and client when updating resource invokes correct method on router
- [x] DataSource with router and client when updating resource passes correct parameters to router
- [x] DataSource with router and client when updating resource client receives correct data from router for execution
- [x] DataSource with router and client when deleting resource invokes execute request on client
- [x] DataSource with router and client when deleting resource invokes correct method on router
- [x] DataSource with router and client when deleting resource passes correct parameters to router
- [x] DataSource with router and client when deleting resource client receives correct data from router for execution
- [x] DataSource with path and client when creating resource invokes execute request on client
- [x] DataSource with path and client when creating resource client receives correct data for execution
- [x] DataSource with path and client when creating resource client receives userInfo for execution
- [x] DataSource with path and client when fetching single resource invokes execute request on client
- [x] DataSource with path and client when fetching single resource client receives correct data for execution
- [x] DataSource with path and client when fetching resource collection with custom pagination invokes execute request on client
- [x] DataSource with path and client when fetching resource collection with custom pagination client receives correct data for execution
- [x] DataSource with path and client when fetching resource collection with page based pagination invokes execute request on client
- [x] DataSource with path and client when fetching resource collection with page based pagination client receives correct data for execution
- [x] DataSource with path and client when fetching resource collection with offset based pagination invokes execute request on client
- [x] DataSource with path and client when fetching resource collection with offset based pagination client receives correct data for execution
- [x] DataSource with path and client when fetching resource collection with cursor based pagination invokes execute request on client
- [x] DataSource with path and client when fetching resource collection with cursor based pagination client receives correct data for execution
- [x] DataSource with path and client when updating resource invokes execute request on client
- [x] DataSource with path and client when updating resource client receives correct data for execution
- [x] DataSource with path and client when deleting resource invokes execute request on client
- [x] DataSource with path and client when deleting resource client receives correct data for execution
- [x] Deserializer when deserializing resource collection maps correctly
- [x] Deserializer when deserializing single resource and error data provided with source object included in errors maps to errors object
- [x] Deserializer when deserializing single resource and error data provided with source object included in errors maps to errors object 2
- [x] Deserializer when deserializing document with polymorphic objects in relationships maps correctly
- [x] Deserializer when deserializing single resource maps correctly
- [x] Paginated DataSource when fetching first page returns first page document
- [x] Paginated DataSource when fetching first page when fetching next page returns next page document
- [x] Paginated DataSource when fetching first page returns first page document 2
- [x] Paginated DataSource when fetching first page when fetching first page of document returns first page document
- [x] Paginated DataSource when fetching first page returns first page document 3
- [x] Paginated DataSource when fetching first page when appending next page document is appended
- [x] Paginated DataSource when fetching first page when appending next page included is appended
- [x] Paginated DataSource when fetching first page returns first page document 4
- [x] Paginated DataSource when fetching first page when reloading current page receives page
- [x] Paginated DataSource when fetching first page returns first page document 5
- [x] Paginated DataSource when fetching first page when fetching previous page receives page
- [x] Paginated DataSource when fetching first page returns first page document 6
- [x] Paginated DataSource when fetching first page when fetching last page returns last page document
- [x] Serializer when serializing resource collection maps correctly
- [x] Serializer when serializing resource collection returns document data
- [x] Serializer when serializing resource collection returns document dictionary
- [x] Serializer when serializing single resource maps correctly
- [x] Serializer when serializing single resource returns document data
- [x] Serializer when serializing single resource returns document dictionary

## Contributing
Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License
[MIT](https://choosealicense.com/licenses/mit/)
