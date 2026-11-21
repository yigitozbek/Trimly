import Foundation

/// Language for category folder and tag names (not the whole app UI).
public enum Language: String, Codable, Sendable, CaseIterable, Identifiable {
    case tr
    case en
    case ja
    case fr
    case it
    case ko

    public var id: String { rawValue }

    /// Native label shown in the Settings picker.
    public var displayName: String {
        switch self {
        case .tr: "Türkçe"
        case .en: "English"
        case .ja: "日本語"
        case .fr: "Français"
        case .it: "Italiano"
        case .ko: "한국어"
        }
    }

    /// Placeholder description when a file has no usable name stem.
    public var unnamedFileLabel: String {
        switch self {
        case .tr: "Dosya"
        case .en: "File"
        case .ja: "ファイル"
        case .fr: "Fichier"
        case .it: "File"
        case .ko: "파일"
        }
    }
}
