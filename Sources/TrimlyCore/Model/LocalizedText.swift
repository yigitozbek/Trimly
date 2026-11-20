import Foundation

public struct LocalizedText: Codable, Equatable, Sendable {
    public var tr: String
    public var en: String

    public init(tr: String, en: String) {
        self.tr = tr
        self.en = en
    }

    public func value(_ language: Language) -> String {
        switch language {
        case .tr: tr
        case .en: en
        }
    }
}
