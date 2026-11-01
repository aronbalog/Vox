import Foundation
import ObjectiveC

/// Connects `Resource` subclasses to the Objective-C runtime.
///
/// Every `@objc dynamic` property declared on a `Resource` subclass gets its getter and setter
/// replaced with implementations that read from and write to the resource's JSON. Classes are
/// prepared lazily, the first time one of their instances is created, instead of scanning every
/// class in the process at launch.
enum ResourceRuntime {
    private static let lock = NSRecursiveLock()
    private static var preparedClasses = Set<ObjectIdentifier>()
    private static var classesByType: [String: Resource.Type] = [:]
    private static var scannedClassCount: Int32 = -1

    /// Installs the JSON-backed accessors of `resourceClass` and its superclasses and registers
    /// the class for its `resourceType`.
    static func prepare(_ resourceClass: Resource.Type) {
        lock.lock()
        defer { lock.unlock() }

        prepareLocked(resourceClass)
    }

    /// The class registered for a JSON:API `type`, if any.
    ///
    /// When no class is registered yet, the runtime is scanned for `Resource` subclasses. The scan
    /// is repeated only when new classes have been loaded since the previous one.
    static func resourceClass(for type: String) -> Resource.Type? {
        lock.lock()
        defer { lock.unlock() }

        if let resourceClass = classesByType[type] {
            return resourceClass
        }

        scanLoadedClassesIfNeeded()

        return classesByType[type]
    }

    private static func prepareLocked(_ resourceClass: AnyClass) {
        guard resourceClass != Resource.self,
              !preparedClasses.contains(ObjectIdentifier(resourceClass)) else {
            return
        }

        if let superclass = class_getSuperclass(resourceClass), superclass is Resource.Type {
            prepareLocked(superclass)
        }

        installAccessors(on: resourceClass)
        registerLocked(resourceClass)
        preparedClasses.insert(ObjectIdentifier(resourceClass))
    }

    private static func registerLocked(_ resourceClass: AnyClass) {
        guard let resourceClass = resourceClass as? Resource.Type,
              let type = declaredResourceType(of: resourceClass) else {
            return
        }

        if let registeredClass = classesByType[type] {
            #if DEBUG
            if registeredClass != resourceClass {
                print("[Vox] Both \(registeredClass) and \(resourceClass) declare resource type \"\(type)\"; \(registeredClass) is used.")
            }
            #endif
            return
        }

        classesByType[type] = resourceClass
    }

    /// The class's `resourceType`, or `nil` when the class doesn't override it itself.
    ///
    /// Abstract intermediate subclasses and subclasses inheriting the type of a concrete superclass
    /// are not registered, and their `resourceType` is never called.
    private static func declaredResourceType(of resourceClass: Resource.Type) -> String? {
        guard let metaclass = object_getClass(resourceClass) else {
            return nil
        }

        var methodCount: UInt32 = 0

        guard let methods = class_copyMethodList(metaclass, &methodCount) else {
            return nil
        }
        defer { free(methods) }

        let selector = NSSelectorFromString("resourceType")
        let declaresResourceType = (0..<Int(methodCount)).contains { index in
            method_getName(methods[index]) == selector
        }

        return declaresResourceType ? resourceClass.resourceType : nil
    }

    private static func scanLoadedClassesIfNeeded() {
        let classCount = objc_getClassList(nil, 0)

        guard classCount != scannedClassCount else {
            return
        }

        let classes = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(classCount))
        defer { classes.deallocate() }

        let copiedCount = objc_getClassList(AutoreleasingUnsafeMutablePointer<AnyClass>(classes), classCount)
        scannedClassCount = classCount

        for index in 0..<Int(min(classCount, copiedCount)) {
            let loadedClass: AnyClass = classes[index]

            if isStrictSubclassOfResource(loadedClass) {
                registerLocked(loadedClass)
            }
        }
    }

    private static func isStrictSubclassOfResource(_ candidate: AnyClass) -> Bool {
        var superclass = class_getSuperclass(candidate)

        while let current = superclass {
            if current == Resource.self {
                return true
            }
            superclass = class_getSuperclass(current)
        }

        return false
    }

    private static func installAccessors(on resourceClass: AnyClass) {
        var propertyCount: UInt32 = 0

        guard let properties = class_copyPropertyList(resourceClass, &propertyCount) else {
            return
        }
        defer { free(properties) }

        for index in 0..<Int(propertyCount) {
            guard let property = PropertyDescription(properties[index]) else {
                continue
            }

            installAccessors(for: property, on: resourceClass)
        }
    }

    private static func installAccessors(for property: PropertyDescription, on resourceClass: AnyClass) {
        let key = property.name

        let getter: @convention(block) (Resource) -> AnyObject? = { resource in
            return resource.value(forKey: key).map { $0 as AnyObject }
        }

        let setter: @convention(block) (Resource, AnyObject?) -> Void = { resource, value in
            resource.setValue(value, forKey: key)
        }

        class_replaceMethod(resourceClass, property.getter, imp_implementationWithBlock(getter), "@@:")

        if !property.isReadOnly {
            class_replaceMethod(resourceClass, property.setter, imp_implementationWithBlock(setter), "v@:@")
        }
    }
}

/// The parts of an Objective-C property declaration needed to replace its accessors.
private struct PropertyDescription {
    let name: String
    let getter: Selector
    let setter: Selector
    let isReadOnly: Bool

    /// Returns `nil` for properties that can't be backed by JSON, such as primitive types and blocks.
    init?(_ property: objc_property_t) {
        let name = String(cString: property_getName(property))

        var attributeCount: UInt32 = 0
        guard let attributes = property_copyAttributeList(property, &attributeCount) else {
            return nil
        }
        defer { free(attributes) }

        var typeEncoding = ""
        var customGetter: String?
        var customSetter: String?
        var isReadOnly = false

        for index in 0..<Int(attributeCount) {
            let attribute = attributes[index]
            let value = String(cString: attribute.value)

            switch String(cString: attribute.name) {
            case "T": typeEncoding = value
            case "G": customGetter = value
            case "S": customSetter = value
            case "R": isReadOnly = true
            default: break
            }
        }

        guard typeEncoding.hasPrefix("@"), typeEncoding != "@?" else {
            return nil
        }

        self.name = name
        self.getter = NSSelectorFromString(customGetter ?? name)
        self.setter = NSSelectorFromString(customSetter ?? "set\(name.prefix(1).uppercased())\(name.dropFirst()):")
        self.isReadOnly = isReadOnly
    }
}
