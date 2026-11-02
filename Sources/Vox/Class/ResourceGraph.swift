import Foundation

/// The resource objects of a document, or of resources linked together in code.
///
/// Resources keep their graph alive, while the graph only keeps weak references to resource
/// instances. When a relationship is read, the graph returns the live instance of the related
/// resource or creates one from the stored JSON. Relationships therefore keep working after the
/// document that delivered them is gone, and resources with cyclic relationships don't leak.
///
/// Assigning a resource of one graph to a resource of another merges the graphs. Merged graphs
/// drop the objects that can no longer be reached from a live instance once they have doubled in
/// size, so a long-lived graph doesn't accumulate the objects of short-lived resources.
final class ResourceGraph {
    /// Guards every graph, the resource objects in it and the storage of every resource.
    ///
    /// A single lock keeps assignments between resources of different graphs, which merge the
    /// graphs, free of lock-ordering deadlocks. The critical sections are short dictionary
    /// operations.
    static let lock = Lock()
    
    private static let minimumCollectionThreshold = 1024
    
    private(set) var objects: [ObjectIdentifier: ResourceObject] = [:]
    private var objectsByKey: [ResourceKey: ResourceObject] = [:]
    private var instances: [ObjectIdentifier: WeakResource] = [:]
    private var mergedGraph: ResourceGraph?
    private var collectionThreshold = ResourceGraph.minimumCollectionThreshold
    
    /// The graph holding this graph's objects, which is a different one after a merge.
    var current: ResourceGraph {
        guard let mergedGraph else {
            return self
        }
        
        let current = mergedGraph.current
        self.mergedGraph = current
        
        return current
    }
    
    /// Adds `object` to the graph. When the graph contains an object with the same key already,
    /// the members of `object` it lacks are added to it and the existing object is returned.
    @discardableResult
    func insert(_ object: ResourceObject) -> ResourceObject {
        let keys = object.keys
        
        if let existingObject = keys.lazy.compactMap({ self.objectsByKey[$0] }).first {
            existingObject.merge(object)
            index(existingObject)
            
            return existingObject
        }
        
        objects[ObjectIdentifier(object)] = object
        index(object)
        
        return object
    }
    
    /// Makes the keys of `object` refer to it, unless they refer to another object already.
    private func index(_ object: ResourceObject) {
        for key in object.keys where objectsByKey[key] == nil {
            objectsByKey[key] = object
        }
    }
    
    func object(for reference: ResourceReference) -> ResourceObject? {
        switch reference {
        case .identifier(let key, _):
            return objectsByKey[key]
        case .object(let identifier):
            return objects[identifier]
        }
    }
    
    /// The live instance of `object`, or a new one when there's none. Objects of types without a
    /// registered class are represented by plain `Resource` instances.
    func instance(for object: ResourceObject) -> Resource {
        if let instance = instances[ObjectIdentifier(object)]?.resource {
            return instance
        }
        
        let resourceClass = ResourceRuntime.resourceClass(for: object.type) ?? Resource.self
        let instance = resourceClass.init()
        instance.bind(to: object, in: self)
        
        return instance
    }
    
    func instance(for reference: ResourceReference) -> Resource? {
        object(for: reference).map(instance(for:))
    }
    
    /// Records `instance` as the live instance of `object`.
    func register(_ instance: Resource, for object: ResourceObject) {
        instances[ObjectIdentifier(object)] = WeakResource(resource: instance)
    }
    
    /// Updates the keys of `object` after its `id` or `lid` changed.
    func updateKeys(of object: ResourceObject, replacing oldKeys: [ResourceKey]) {
        for key in oldKeys where objectsByKey[key] === object {
            objectsByKey[key] = nil
        }
        
        index(object)
    }
    
    /// Makes resource identifiers with the keys of `object` resolve to it.
    func prefer(_ object: ResourceObject) {
        for key in object.keys {
            objectsByKey[key] = object
        }
    }
    
    /// Moves the objects of the smaller graph into the larger one and returns the larger one.
    static func merge(_ first: ResourceGraph, _ second: ResourceGraph) -> ResourceGraph {
        let first = first.current
        let second = second.current
        
        guard first !== second else {
            return first
        }
        
        let (survivor, absorbed) = first.objects.count >= second.objects.count ? (first, second) : (second, first)
        survivor.absorb(absorbed)
        
        return survivor
    }
    
    /// Moves the objects of `graph`, which holds a later response, into this graph. An object
    /// with the key of an object in this graph updates that object instead of being added, so
    /// the resources of this graph keep their identity and show the newer members.
    func update(with graph: ResourceGraph) {
        let target = current
        let graph = graph.current
        
        guard target !== graph else {
            return
        }
        
        for (identifier, object) in graph.objects {
            if let existingObject = object.keys.lazy.compactMap({ target.objectsByKey[$0] }).first {
                existingObject.update(with: object)
                target.index(existingObject)
            } else {
                target.objects[identifier] = object
                target.instances[identifier] = graph.instances[identifier]
                target.index(object)
            }
        }
        
        target.finishAbsorbing(graph)
    }
    
    /// The object with any of the keys of `object`, which is `object` itself unless a graph
    /// update replaced it.
    func object(matching object: ResourceObject) -> ResourceObject? {
        object.keys.lazy.compactMap { self.objectsByKey[$0] }.first
    }
    
    private func absorb(_ graph: ResourceGraph) {
        objects.merge(graph.objects) { object, _ in object }
        objectsByKey.merge(graph.objectsByKey) { object, _ in object }
        instances.merge(graph.instances) { instance, _ in instance }
        
        finishAbsorbing(graph)
    }
    
    private func finishAbsorbing(_ graph: ResourceGraph) {
        graph.objects = [:]
        graph.objectsByKey = [:]
        graph.instances = [:]
        graph.mergedGraph = self
        
        if objects.count >= collectionThreshold {
            collectGarbage()
        }
    }
    
    /// Removes the objects that can't be reached through relationships from an object with a
    /// live instance.
    ///
    /// Decoding inserts objects before any instance exists, so this must only run on graphs
    /// whose instances have been created.
    private func collectGarbage() {
        var reachable = Set<ObjectIdentifier>()
        var pending = instances.compactMap { identifier, instance in
            instance.resource == nil ? nil : objects[identifier]
        }
        
        while let object = pending.popLast() {
            guard reachable.insert(ObjectIdentifier(object)).inserted else {
                continue
            }
            
            for relationship in object.relationships.values {
                switch relationship.data {
                case .toOne(let reference?)?:
                    pending.append(contentsOf: self.object(for: reference).map { [$0] } ?? [])
                case .toMany(let references)?:
                    pending.append(contentsOf: references.compactMap(self.object(for:)))
                default:
                    break
                }
            }
        }
        
        objects = objects.filter { reachable.contains($0.key) }
        objectsByKey = objectsByKey.filter { reachable.contains(ObjectIdentifier($0.value)) }
        instances = instances.filter { $0.value.resource != nil }
        
        for object in objects.values {
            index(object)
        }
        
        collectionThreshold = max(ResourceGraph.minimumCollectionThreshold, objects.count * 2)
    }
}

private struct WeakResource {
    weak var resource: Resource?
}
