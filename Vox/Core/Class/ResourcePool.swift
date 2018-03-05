import Foundation

class ResourcePool {
    private let queue: DispatchQueue
    
    private var mapTable: NSMapTable<NSString, Resource>
    
    init(queue: DispatchQueue) {
        self.queue = queue
        self.mapTable = NSMapTable<NSString, Resource>(keyOptions: [.strongMemory], valueOptions: [.strongMemory])
    }
    
    func addResource(_ resource: Resource) {
        queue.async(flags: .barrier) {
            self.mapTable.setObject(resource, forKey: self.keyForResource(resource) as NSString)
        }
    }
    
    func resource(forBasicObject basicObject: [String: String]) -> Resource? {
        var value: Resource?
        
        queue.sync() { () -> Void in
            value = mapTable.object(forKey: keyForBasicObject(basicObject) as NSString)
        }
        
        return value
    }
    
    func reassignContext(_ context: Context) {
        queue.async(flags: .barrier) {
            let newMapTable = NSMapTable<NSString, Resource>(keyOptions: [.strongMemory], valueOptions: [.weakMemory], capacity: self.mapTable.count)
        
            self.mapTable.dictionaryRepresentation().forEach { (key, resource) in
                resource.reassignContext(context)
                
                newMapTable.setObject(resource, forKey: self.keyForResource(resource) as NSString)
            }
            
            self.mapTable = newMapTable
        }
    }
    
    private func keyForBasicObject(_ basicObject: [String: String]) -> String {
        return basicObject["id"]! + "_" + basicObject["type"]!
    }
    
    private func keyForResource(_ resource: Resource) -> String {
        return resource.id! + "_" + resource.type
    }
}
