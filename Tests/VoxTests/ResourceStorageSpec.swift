import Foundation
import Testing

@testable import Vox

// Plain stored properties are not JSON-backed; these models are accessed through subscripts so the
// suite runs on platforms without the Objective-C runtime as well.
fileprivate final class Author: Resource, @unchecked Sendable {
    override class var resourceType: String {
        return "storage-authors"
    }
    
    var name: String?
    var books: [Book]?
}

fileprivate final class Book: Resource, @unchecked Sendable {
    override class var resourceType: String {
        return "storage-books"
    }
    
    var title: String?
    var pages: Int?
    var tags: [String]?
    var author: Author?
    var related: [Book]?
}

fileprivate let bookDocument = Data("""
{
    "data": {
        "type": "storage-books",
        "id": "b1",
        "attributes": {
            "title": "Dune",
            "pages": 412,
            "tags": ["sci-fi"]
        },
        "relationships": {
            "author": {
                "data": { "type": "storage-authors", "id": "a1" },
                "links": { "related": "/books/b1/author" }
            },
            "related": {
                "data": [{ "type": "storage-books", "id": "b2", "meta": { "order": 1 } }]
            }
        }
    },
    "included": [
        {
            "type": "storage-authors",
            "id": "a1",
            "attributes": { "name": "Frank" },
            "relationships": {
                "books": { "data": [{ "type": "storage-books", "id": "b1" }] }
            }
        },
        {
            "type": "storage-books",
            "id": "b2",
            "attributes": { "title": 42 },
            "relationships": {
                "author": { "data": { "type": "storage-books", "id": "b1" } }
            }
        }
    ]
}
""".utf8)

@Suite("Resource storage")
struct ResourceStorageSpec {
    init() {
        ResourceRuntime.register(Author.self)
        ResourceRuntime.register(Book.self)
    }
    
    private func decodeBook() throws -> Book {
        return try #require(try Deserializer.Single<Book>().deserialize(data: bookDocument).data)
    }
    
    @Test("decoded values are typed by the declared properties")
    func typedValues() throws {
        let book = try decodeBook()
        
        #expect(book.id == "b1")
        #expect(book.type == "storage-books")
        #expect(book["title"] as? String == "Dune")
        #expect(book["pages"] as? Int == 412)
        #expect(book["tags"] as? [String] == ["sci-fi"])
    }
    
    @Test("values that don't match the declared type read as nil")
    func typeMismatch() throws {
        let book = try decodeBook()
        let related = try #require((book["related"] as? [Book])?.first)
        
        #expect(related.id == "b2")
        #expect(related["title"] == nil)
        #expect(related["author"] == nil)
        #expect(related.attributes["title"] as? Int == 42)
    }
    
    @Test("relationships keep working after the document is released")
    func relationshipsOutliveDocument() throws {
        let book = try decodeBook()
        let author = try #require(book["author"] as? Author)
        
        #expect(author["name"] as? String == "Frank")
    }
    
    @Test("each resource object has a single live instance")
    func identity() throws {
        let book = try decodeBook()
        let author = try #require(book["author"] as? Author)
        
        #expect(book["author"] as? Author === author)
        #expect((author["books"] as? [Book])?.first === book)
    }
    
    @Test("released instances are recreated from the same resource object")
    func recreation() throws {
        let book = try decodeBook()
        
        var author = book["author"] as? Author
        author?["name"] = "Frank Herbert"
        author = nil
        
        let recreated = try #require(book["author"] as? Author)
        #expect(recreated["name"] as? String == "Frank Herbert")
    }
    
    @Test("resources release each other despite cyclic relationships")
    func noRetainCycles() throws {
        weak var weakBook: Book?
        weak var weakAuthor: Author?
        
        try drainingAutoreleasePool {
            let book = try decodeBook()
            let author = try #require(book["author"] as? Author)
            #expect((author["books"] as? [Book])?.first === book)
            
            weakBook = book
            weakAuthor = author
        }
        
        #expect(weakBook == nil)
        #expect(weakAuthor == nil)
    }
    
    @Test("objects of released resources don't accumulate in a long-lived graph")
    func unreachableObjectsAreCollected() throws {
        let book = try decodeBook()
        let author = try #require(book["author"] as? Author)
        
        for index in 0..<5000 {
            drainingAutoreleasePool {
                let draft = Book()
                draft.id = "draft-\(index)"
                draft["author"] = author
            }
        }
        
        let graph = ResourceGraph.lock.withLock { author.storageLocked().graph }
        #expect(graph.objects.count <= 1024)
        #expect(book["author"] as? Author === author)
        #expect((author["books"] as? [Book])?.first === book)
        #expect((book["related"] as? [Book])?.first?.id == "b2")
    }
    
    @Test("a resource from another document can be assigned")
    func crossDocumentAssignment() throws {
        let book = try decodeBook()
        let otherBook = try decodeBook()
        let otherAuthor = try #require(otherBook["author"] as? Author)
        otherAuthor["name"] = "Brian"
        
        let author = Author()
        author.id = "a2"
        author["name"] = "Kevin"
        book["author"] = author
        
        #expect(book["author"] as? Author === author)
        #expect((book.relationships["author"] as? [String: Any])?["data"] as? [String: String] == ["type": "storage-authors", "id": "a2"])
        
        otherBook["author"] = author
        #expect(otherBook["author"] as? Author === author)
        #expect(otherAuthor["name"] as? String == "Brian")
    }
    
    @Test("an assigned resource replaces the decoded one with the same identity")
    func assignedResourceWins() throws {
        let book = try decodeBook()
        
        let author = Author()
        author.id = "a1"
        author["name"] = "Replacement"
        book["author"] = author
        
        #expect(book["author"] as? Author === author)
        #expect((book["author"] as? Author)?["name"] as? String == "Replacement")
    }
    
    @Test("an id set after assignment is serialized")
    func lateIdentifier() throws {
        let book = Book()
        let author = Author()
        book["author"] = author
        author.id = "late"
        
        let relationship = try #require(book.relationships["author"] as? [String: Any])
        #expect(relationship["data"] as? [String: String] == ["type": "storage-authors", "id": "late"])
    }
    
    @Test("serializing a relationship to a resource without id throws")
    func missingRelatedIdentifier() {
        let book = Book()
        book["author"] = Author()
        
        #expect(throws: JSONAPIError.self) {
            try book.documentDictionary()
        }
        #expect(book.relationships.isEmpty)
    }
    
    @Test("an empty array assigned to an attribute stays an attribute")
    func emptyArrayAttribute() throws {
        let book = try decodeBook()
        book["tags"] = [String]()
        
        #expect(book.attributes["tags"] as? [String] == [])
        #expect(book.relationships["tags"] == nil)
    }
    
    @Test("an empty to-many relationship serializes as an empty array")
    func emptyToMany() throws {
        let book = try decodeBook()
        book["related"] = [Book]()
        
        let relationship = try #require(book.relationships["related"] as? [String: Any])
        #expect((relationship["data"] as? [Any])?.isEmpty == true)
        #expect((book["related"] as? [Book])?.isEmpty == true)
    }
    
    @Test("setting a relationship to nil removes its linkage")
    func nilRemovesLinkage() throws {
        let book = try decodeBook()
        book["author"] = nil
        book["related"] = nil
        
        #expect(book["author"] == nil)
        #expect(book.relationships["author"] == nil)
        #expect(book.relationships["related"] == nil)
    }
    
    @Test("undeclared members are stored by value")
    func undeclaredMembers() throws {
        let book = try decodeBook()
        let author = try #require(book["author"] as? Author)
        
        book["subtitle"] = "Part One"
        book["editor"] = author
        
        #expect(book["subtitle"] as? String == "Part One")
        #expect(book["editor"] as? Author === author)
        #expect(book.attributes["subtitle"] as? String == "Part One")
        #expect(book.relationships["editor"] != nil)
    }
    
    @Test("collections serialize resources with their identifiers")
    func collectionDocument() throws {
        let first = Book()
        first.id = "1"
        first["title"] = "One"
        let second = Book()
        second.id = "2"
        second["author"] = first
        
        let document = try [first, second].documentDictionary()
        let data = try #require(document["data"] as? [[String: Any]])
        
        #expect(data.count == 2)
        #expect(data[0]["id"] as? String == "1")
        #expect((data[1]["relationships"] as? [String: Any])?["author"] != nil)
        
        #expect(throws: JSONAPIError.self) {
            try [Book()].documentDictionary()
        }
    }
    
    @Test("resources can be read and written from many tasks at once")
    func concurrentAccess() async throws {
        let book = try decodeBook()
        
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<200 {
                group.addTask {
                    book["title"] = "Title \(index)"
                    
                    let other = Book()
                    other.id = "concurrent-\(index)"
                    other["author"] = book["author"] as? Author
                    other["related"] = [book]
                    
                    _ = try? other.documentDictionary()
                    _ = book.relationships
                }
            }
        }
        
        #expect((book["title"] as? String)?.hasPrefix("Title") == true)
        #expect((book["author"] as? Author)?["name"] as? String == "Frank")
    }
}

private func drainingAutoreleasePool(_ body: () throws -> Void) rethrows {
    #if canImport(ObjectiveC)
    try autoreleasepool(invoking: body)
    #else
    try body()
    #endif
}
