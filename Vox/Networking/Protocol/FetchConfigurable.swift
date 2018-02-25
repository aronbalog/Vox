import Foundation

public typealias FetchConfigurable = FetchFieldable &
                                     FetchIncludable &
                                     FetchSortable &
                                     FetchFilterable &
                                     FetchPageable

