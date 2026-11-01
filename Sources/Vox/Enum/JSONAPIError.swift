public enum JSONAPIError: Error {
    /// A resource couldn't be serialized, for example because a related resource has no `id`.
    case serialization
    /// The server responded with error objects.
    case API(_: [ErrorObject])
    /// The data isn't a JSON:API document the request can handle.
    case invalidDocument(reason: String)
}
