import Foundation

/// Converts `Date` attributes from and to ISO 8601 strings.
enum ISO8601DateCoding {
    private struct Formatters {
        let dateTime = Formatters.make([.withInternetDateTime])
        let fractionalDateTime = Formatters.make([.withInternetDateTime, .withFractionalSeconds])
        let fullDate = Formatters.make([.withFullDate])
        
        private static func make(_ options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            
            return formatter
        }
    }
    
    private static let formatters = Locked(Formatters())
    
    /// Parses date-times with or without fractional seconds, and dates without a time, which are
    /// interpreted as midnight UTC.
    static func date(from string: String) -> Date? {
        return formatters.withLock { formatters in
            formatters.dateTime.date(from: string)
                ?? formatters.fractionalDateTime.date(from: string)
                ?? formatters.fullDate.date(from: string)
        }
    }
    
    /// A UTC date-time, with fractional seconds when the date has them.
    static func string(from date: Date) -> String {
        let hasFractionalSeconds = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) != 0
        
        return formatters.withLock { formatters in
            (hasFractionalSeconds ? formatters.fractionalDateTime : formatters.dateTime).string(from: date)
        }
    }
}
