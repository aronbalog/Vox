import Foundation

extension StringProtocol {
    /// The string with the characters that aren't in `allowedCharacters` percent-encoded.
    func percentEncoded(allowing allowedCharacters: CharacterSet) -> String {
        // Encoding fails only for strings that aren't valid Unicode, which Swift strings always are.
        addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
    }
}
