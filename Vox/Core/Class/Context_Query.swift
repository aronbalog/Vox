import Foundation

extension Context {
    func value(forKey key: String, inResource resource: Resource) -> Any? {
        var value: Any?
        
        self.queue.sync() { () -> Void in
            // try in attributes
            if let _value = resource.object?.value(forKeyPath: "attributes.\(key)") {
                if _value is NSNull {
                    value = nil
                } else {
                    value = _value
                }
                
            } else if let relationshipDocumentData = resource.object?.value(forKeyPath: "relationships.\(key)") as? NSMutableDictionary {
                let data = relationshipDocumentData["data"]
                if let arrayOfBasicObjects = data as? NSMutableArray {
                    
                    value = arrayOfBasicObjects.flatMap({ (basicObject) -> Resource? in
                        return resourcePool.resource(forBasicObject: basicObject as! [String: String])
                    })
                } else if let basicObject = data as? NSMutableDictionary {
                    value = resourcePool.resource(forBasicObject: basicObject as! [String: String])
                } else if data is NSNull {
                    value = nil
                }
            }
        }
        
        return value
    }
    
    func setValue(_ value: Any?, forKey key: String, inResource resource: Resource) {
        if let resource = value as? Resource {
            resource.context = self
            resourcePool.addResource(resource)
        } else if let collection = value as? [Resource] {
            collection.forEach({ (resource) in
                resource.context = self
                resourcePool.addResource(resource)
            })
        }
        
        self.queue.async(flags: .barrier) {
            // determine where to store value
            if let value = value as? Resource {
                self.setRelationship(value, forKey: key, inResource: resource)
            } else if let value = value as? [Resource] {
                self.setRelationship(value, forKey: key, inResource: resource)
            } else {
                self.setAttribute(value, forKey: key, inResource: resource)
            }
        }
    }
    
    private func setAttribute(_ value: Any?, forKey key: String, inResource resource: Resource) {
        let attributes = self.attributes(for: resource)
        
        let value = isValueNull(value) ? NSNull() : value
        
        attributes.setValue(value, forKey: key)
    }
    
    private func isValueNull(_ value: Any?) -> Bool {
        if value == nil {
            // nil is not `null`
            return false
        }
        
        if let value = value as? NullableAware {
            return value.isNull
        } else if let value = value as? String {
            return value.isNull
        } else if let value = value as? [String] {
            return value.isNull
        } else if let value = value as? [String: Any] {
            return value.isNull
        } else if let value = value as? [[String: Any]] {
            return value.isNull
        } else if let value = value as? [NSNumber] {
            return value.isNull
        }
        
        return false
    }
    
    private func setRelationship(_ value: Resource?, forKey key: String, inResource resource: Resource) {
        let relationships = self.relationships(for: resource)
        
        guard let value = value else {
            relationships.removeObject(forKey: key)
            return
        }
        
        var mappedValue: Any? = value
        
        if value.isNull == true {
            mappedValue = nil
        } else {
            guard let id = value.id else {
                fatalError("Added relationship must have id")
            }
            
            mappedValue = NSMutableDictionary(dictionary: [
                "id": id,
                "type": value.type
                ])
        }
        
        relationships[key] = NSMutableDictionary(dictionary: [
            "data": mappedValue ?? NSNull()
            ])
    }
    
    private func setRelationship(_ value: [Resource]?, forKey key: String, inResource resource: Resource) {
        let relationships = self.relationships(for: resource)
        
        if value == nil {
            relationships.removeObject(forKey: key)
            return
        }
        
        var mappedValue: Any? = value
        
        if value?.isNull == true {
            mappedValue = nil
        } else {
            let _mappedValue = NSMutableArray()
            value?.forEach({ (resource) in
                guard let id = resource.id else {
                    fatalError("Added relationship must have id")
                }

                let object = NSMutableDictionary(dictionary: [
                    "id": id,
                    "type": resource.type
                    ])
                _mappedValue.add(object)
            })
            mappedValue = _mappedValue
        }
        
        relationships[key] = NSMutableDictionary(dictionary: [
            "data": mappedValue ?? NSNull()
            ])
    }
    
    private func attributes(for resource: Resource) -> NSMutableDictionary {
        if let attributes = resource.object?["attributes"] as? NSMutableDictionary {
            return attributes
        }
        
        let dictionary = NSMutableDictionary()
        resource.object?["attributes"] = dictionary
        
        return dictionary
    }
    
    private func relationships(for resource: Resource) -> NSMutableDictionary {
        if let relationships = resource.object?["relationships"] as? NSMutableDictionary {
            return relationships
        }
        
        let dictionary = NSMutableDictionary()
        resource.object?["relationships"] = dictionary
        
        return dictionary
    }
}

