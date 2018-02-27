#import "BaseResource.h"
#import <objc/runtime.h>

#import "Vox/Vox-Swift.h"

@class Context;

@implementation BaseResource
+ (SEL)getterForPropertyWithName:(NSString*)name {
    const char* propertyName = [name cStringUsingEncoding:NSASCIIStringEncoding];
    objc_property_t prop = class_getProperty(self, propertyName);
    
    const char *selectorName = property_copyAttributeValue(prop, "G");
    if (selectorName == NULL) {
        selectorName = [name cStringUsingEncoding:NSASCIIStringEncoding];
    }
    NSString* selectorString = [NSString stringWithCString:selectorName encoding:NSASCIIStringEncoding];
    return NSSelectorFromString(selectorString);
}
    
+ (SEL)setterForPropertyWithName:(NSString*)name {
    const char* propertyName = [name cStringUsingEncoding:NSASCIIStringEncoding];
    
    NSString* selectorString;
    
    char firstChar = (char)toupper(propertyName[0]);
    NSString* capitalLetter = [NSString stringWithFormat:@"%c", firstChar];
    NSString* reminder = [NSString stringWithCString: propertyName+1
                                            encoding: NSASCIIStringEncoding];
    selectorString = [@[@"set", capitalLetter, reminder, @":"] componentsJoinedByString:@""];
    
    return NSSelectorFromString(selectorString);
}
    
+ (void)load
{
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = NULL;
    
    classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 0; i < numClasses; i++) {
        Class superClass = classes[i];
        do {
            superClass = class_getSuperclass(superClass);
        } while(superClass && superClass != [Resource self]);
        
        if (!superClass) {
            continue;
        }
        
        [result addObject:classes[i]];
    }
    
    free(classes);
    
    for (Class resourceClass in result) {
        unsigned int outCount, i;
        objc_property_t *properties = class_copyPropertyList(resourceClass, &outCount);
        for(i = 0; i < outCount; i++) {
            objc_property_t property = properties[i];
            const char *attrs = property_getAttributes(property);
            NSString *name = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            
            SEL getter = [self getterForPropertyWithName:name];
            SEL setter = [self setterForPropertyWithName:name];
            
            class_replaceMethod(resourceClass, getter, (IMP)value, attrs);
            class_replaceMethod(resourceClass, setter, (IMP)setValue, attrs);
        }
        
        [Context registerClass:resourceClass];
        
        free(properties);
    }
}
    
id value(Resource *resource, SEL _cmd) {
    NSString *key = NSStringFromSelector(_cmd);
    
    return [resource valueForKey:key];
}
    
void setValue(Resource *resource, SEL _cmd, id value) {
    NSString *key = PropertyNameForSetterSelector(_cmd);
    [resource setValue:value forKey:key];
}
    
NSString* PropertyNameForSetterSelector(SEL selector) {
    NSString *selectorName = NSStringFromSelector(selector);
    NSString *propertyName = [selectorName substringFromIndex:3];
    propertyName = [propertyName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[propertyName substringToIndex:1] lowercaseString]];
    propertyName = [propertyName substringToIndex:propertyName.length - 1];
    
    return propertyName;
}
    
@end
