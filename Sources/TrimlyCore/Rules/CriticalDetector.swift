import Foundation

/// Flags sensitive items (keys, certificates, databases, identity/health/payroll documents).
/// Critical items never send content to the LLM and are never approved automatically.
public struct CriticalDetector: Sendable {
    private let extensions: Set<String>
    private let keywords: [String]

    public init(settings: Settings) {
        self.extensions = Set(settings.criticalExtensions.map { $0.lowercased() })
        self.keywords = settings.criticalKeywords.map { Normalizer.ascii($0).lowercased() }
    }

    public func isCritical(_ item: FileItem) -> Bool {
        let lastExtension = item.fileExtension.split(separator: ".").last.map(String.init) ?? ""
        if extensions.contains(lastExtension) {
            return true
        }
        let tokens = Normalizer.ascii(item.name).lowercased().split { !($0.isLetter || $0.isNumber) }
        return tokens.contains { token in
            keywords.contains { keyword in
                // Short keywords ("tc") must match a whole token so "etc" does not trigger them.
                keyword.count >= 4 ? token.hasPrefix(keyword) : token == keyword
            }
        }
    }
}
