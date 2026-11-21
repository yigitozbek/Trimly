import Foundation

/// Tabs in the Settings scene. Raw values are stable for `@AppStorage` deep-links.
enum SettingsTab: String, CaseIterable, Identifiable {
    case naming
    case target
    case tags
    case trash
    case model
    case ignore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .naming: "Adlandırma"
        case .target: "Hedef"
        case .tags: "Etiketler"
        case .trash: "Çöp"
        case .model: "Model"
        case .ignore: "Hariç tutma"
        }
    }

    var systemImage: String {
        switch self {
        case .naming: "textformat"
        case .target: "folder"
        case .tags: "tag"
        case .trash: "trash"
        case .model: "cpu"
        case .ignore: "eye.slash"
        }
    }

    static let storageKey = "settingsTab"
}
