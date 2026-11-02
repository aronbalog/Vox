import Foundation

/// A request with the query parameters of JSON:API.
public typealias FetchConfigurable = FetchFieldable &
                                     FetchIncludable &
                                     FetchSortable &
                                     FetchFilterable &
                                     FetchPageable

