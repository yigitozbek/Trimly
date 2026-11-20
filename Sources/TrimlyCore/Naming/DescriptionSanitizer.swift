import Foundation

/// Deterministic clean-up of a description (usually an LLM's `suggested_name`) before it enters the naming template.
/// Small models leak dates, extensions and category words into it; the schema cannot prevent that.
public enum DescriptionSanitizer {
    public static let fillerWords: Set<String> = ["dosya", "file", "belge", "document", "yeni", "new", "kopya", "copy"]

    private static let months = "ocak|subat|mart|nisan|mayis|haziran|temmuz|agustos|eylul|ekim|kasim|aralik|"
        + "january|february|march|april|may|june|july|august|september|october|november|december"

    private static let datePatterns: [String] = [
        #"\d{4}[-_.]\d{2}[-_.]\d{2}"#,
        #"\d{2}[.-]\d{2}[.-]\d{4}"#,
        #"\b(19|20)\d{6}\b"#,
        #"\b(\#(months))\s+\d{4}\b"#,
        #"\b\d{4}\s+(\#(months))\b"#
    ]

    public static func sanitize(_ raw: String, originalExtension: String, categoryTerms: [String]) -> String? {
        var text = stripTrailingExtensions(raw.trimmingCharacters(in: .whitespacesAndNewlines), originalExtension: originalExtension)
        text = Normalizer.ascii(text)
        for pattern in datePatterns {
            text = text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }

        var tokens = text.split { !($0.isLetter || $0.isNumber) }.map(String.init)
        let termTokens = categoryTerms.map { term in
            Normalizer.ascii(term).lowercased().split { !($0.isLetter || $0.isNumber) }.map(String.init)
        }.filter { $0.isEmpty == false }

        var changed = true
        while changed && tokens.isEmpty == false {
            changed = false
            let lower = tokens.map { $0.lowercased() }
            if fillerWords.contains(lower[0]) {
                tokens.removeFirst(); changed = true; continue
            }
            if let last = lower.last, fillerWords.contains(last) {
                tokens.removeLast(); changed = true; continue
            }
            if let term = termTokens.first(where: { lower.starts(with: $0) }) {
                tokens.removeFirst(term.count); changed = true; continue
            }
            if let term = termTokens.first(where: { lower.reversed().starts(with: $0.reversed()) }) {
                tokens.removeLast(term.count); changed = true; continue
            }
        }

        let result = Normalizer.slug(tokens.joined(separator: " "), maxLength: 50)
        return result.count < 2 ? nil : result
    }

    private static func stripTrailingExtensions(_ text: String, originalExtension: String) -> String {
        var current = text
        let original = originalExtension.lowercased()
        while true {
            let ext = (current as NSString).pathExtension.lowercased()
            guard ext.isEmpty == false, ext == original || KnownExtensions.all.contains(ext) else {
                return current
            }
            current = (current as NSString).deletingPathExtension
        }
    }
}
