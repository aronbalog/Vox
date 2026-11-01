import Foundation

/// Converts `Date` attributes from and to ISO 8601 strings.
enum ISO8601DateCoding {
    // ISO8601DateFormatter is thread-safe.
    nonisolated(unsafe) private static let dateTimeFormatter = formatter([.withInternetDateTime])
    nonisolated(unsafe) private static let fractionalDateTimeFormatter = formatter([.withInternetDateTime, .withFractionalSeconds])
    nonisolated(unsafe) private static let dateFormatter = formatter([.withFullDate])
    
    /// Parses date-times with or without fractional seconds, and dates without a time, which are
    /// interpreted as midnight UTC.
    static func date(from string: String) -> Date? {
        return dateTimeFormatter.date(from: string)
            ?? fractionalDateTimeFormatter.date(from: string)
            ?? dateFormatter.date(from: string)
    }
    
    /// A UTC date-time, with fractional seconds when the date has them.
    static func string(from date: Date) -> String {
        let hasFractionalSeconds = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) != 0
        
        return (hasFractionalSeconds ? fractionalDateTimeFormatter : dateTimeFormatter).string(from: date)
    }
    
    private static func formatter(_ options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        
        return formatter
    }
}
