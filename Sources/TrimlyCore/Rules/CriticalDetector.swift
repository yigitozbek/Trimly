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
        let lower = item.name.lowercased()
        // Every extension component counts, so `dump.sql.gz` is as sensitive as `dump.sql`.
        let components = lower.split(separator: ".").dropFirst().map(String.init)
        if components.contains(where: extensions.contains) {
            return true
        }
        if lower.contains(/^id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$/) {
            return true
        }
        let tokens = Normalizer.ascii(item.name).lowercased().split { !($0.isLetter || $0.isNumber) }
        return tokens.contains { token in
            keywords.contains { keyword in
                switch keyword.count {
                // Long keywords also match inside glued names ("TCKimlik", "2024Bordro", "MyPassword").
                case 5...: token.contains(keyword)
                case 4: token.hasPrefix(keyword)
                // Short keywords ("tc") must be a whole token so "etc" does not trigger them.
                default: token == keyword
                }
            }
        }
    }
}
