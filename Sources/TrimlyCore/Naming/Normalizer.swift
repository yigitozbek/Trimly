import Foundation

public enum Normalizer {
    private static let turkishMap: [Character: String] = [
        "ç": "c", "ğ": "g", "ı": "i", "İ": "I", "ö": "o", "ş": "s", "ü": "u",
        "Ç": "C", "Ğ": "G", "Ö": "O", "Ş": "S", "Ü": "U"
    ]
    private static let compoundExtensions = ["tar.gz", "tar.bz2", "tar.xz"]

    /// Folds Turkish letters and other diacritics to ASCII and drops whatever is still non-ASCII.
    public static func ascii(_ text: String) -> String {
        let mapped = text.map { turkishMap[$0] ?? String($0) }.joined()
        let stripped = mapped.applyingTransform(.stripDiacritics, reverse: false) ?? mapped
        return String(String.UnicodeScalarView(stripped.unicodeScalars.filter(\.isASCII)))
    }

    /// ASCII words joined by `-`, each word's first letter uppercased; cut at the last whole word within `maxLength`.
    public static func slug(_ text: String, maxLength: Int = 50) -> String {
        let words = ascii(text)
            .split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        var result = ""
        for word in words {
            let candidate = result.isEmpty ? word : result + "-" + word
            if candidate.count > maxLength {
                if result.isEmpty {
                    result = String(word.prefix(maxLength))
                }
                break
            }
            result = candidate
        }
        return result
    }

    /// Lowercased extension, keeping `tar.gz`/`tar.bz2`/`tar.xz`; `""` when the name has no plausible extension.
    public static func fullExtension(of name: String) -> String {
        let lower = name.lowercased()
        if let compound = compoundExtensions.first(where: { lower.hasSuffix("." + $0) && lower.count > $0.count + 1 }) {
            return compound
        }
        let ext = (lower as NSString).pathExtension
        return ext.wholeMatch(of: /[a-z0-9]{1,10}/) != nil ? ext : ""
    }

    /// Normalized name for folders and the `originalNormalized` preset; falls back to the original if nothing survives.
    public static func normalizedFileName(_ name: String, isFolder: Bool) -> String {
        let ext = isFolder ? "" : fullExtension(of: name)
        let stem = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        let base = slug(stem, maxLength: 100)
        guard base.isEmpty == false else {
            return name
        }
        return ext.isEmpty ? base : base + "." + ext
    }
}
