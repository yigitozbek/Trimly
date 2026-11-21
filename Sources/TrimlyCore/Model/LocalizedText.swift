import Foundation

/// Category folder / tag text in every supported language.
/// Older settings JSON with only `tr`/`en` still decode; missing langs fall back to English.
public struct LocalizedText: Codable, Equatable, Sendable {
    public var tr: String
    public var en: String
    public var ja: String
    public var fr: String
    public var it: String
    public var ko: String

    public init(tr: String, en: String, ja: String? = nil, fr: String? = nil, it: String? = nil, ko: String? = nil) {
        self.tr = tr
        self.en = en
        self.ja = ja ?? en
        self.fr = fr ?? en
        self.it = it ?? en
        self.ko = ko ?? en
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tr = try c.decode(String.self, forKey: .tr)
        en = try c.decode(String.self, forKey: .en)
        ja = try c.decodeIfPresent(String.self, forKey: .ja) ?? en
        fr = try c.decodeIfPresent(String.self, forKey: .fr) ?? en
        it = try c.decodeIfPresent(String.self, forKey: .it) ?? en
        ko = try c.decodeIfPresent(String.self, forKey: .ko) ?? en
    }

    public func value(_ language: Language) -> String {
        switch language {
        case .tr: tr
        case .en: en
        case .ja: ja
        case .fr: fr
        case .it: it
        case .ko: ko
        }
    }

    /// All language variants (for matching existing folders / tags).
    public var allValues: [String] { [tr, en, ja, fr, it, ko] }
}
