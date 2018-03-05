import Foundation

class JSONAPIDecoder {
    static func decode<DataType>(data: Data) throws -> Document<DataType> {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers]) as? NSMutableDictionary else {
            throw JSONAPIError.serialization
        }
        
        // precheck if error
        
        let meta     = jsonObject["meta"] as? [String: Any]
        let jsonApi  = jsonObject["jsonApi"] as? [String: Any]
        let links    = jsonObject["links"] as? [String: Any]
        let included = jsonObject["included"] as? [[String: Any]]
        
        let context = Context(dictionary: jsonObject)
        
        let dataType = context.dataType()
        
        switch dataType {
        case .resource(let resource):
            return Document<DataType>(data: resource as? DataType, meta: meta, jsonapi: jsonApi, links: links, included: included, context: context)
        case .collection(let collection):
            return Document<DataType>(data: collection as? DataType, meta: meta, jsonapi: jsonApi, links: links, included: included, context: context)
        case .error(let errors):
            throw JSONAPIError.API(errors)
        case .unknown:
            throw JSONAPIError.serialization
        }
    }
}
