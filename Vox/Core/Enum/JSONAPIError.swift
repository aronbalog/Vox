public enum JSONAPIError: Error {
    case serialization
    case API(_: [ErrorObject])
}
