import Foundation

public enum JSONAPIError: Error {
    /// A resource couldn't be serialized, for example because a related resource has neither `id`
    /// nor `lid`.
    case serialization(reason: String)
    /// The server responded with error objects.
    case API(_: [ErrorObject])
    /// The data isn't a JSON:API document the request can handle.
    case invalidDocument(reason: String)
    /// The server responded with a status code outside 200–299 and without error objects.
    case unacceptableStatusCode(_ statusCode: Int, body: Data)
}
