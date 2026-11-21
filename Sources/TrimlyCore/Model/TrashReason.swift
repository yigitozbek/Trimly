import Foundation

/// Why a file is offered as a Trash candidate (at most one per item).
public enum TrashReason: Codable, Equatable, Sendable {
    case oldInstaller(days: Int)
    case stalePartialDownload
    case duplicate(of: String)
    case emptyFile
    case tempFile

    /// Turkish label shown in the plan and the app.
    public var label: String {
        switch self {
        case .oldInstaller(let days): "\(days) günden eski kurulum dosyası"
        case .stalePartialDownload: "Bayat yarım indirme"
        case .duplicate(let path): "`\(URL(filePath: path).lastPathComponent)` ile aynı içerik"
        case .emptyFile: "Boş dosya"
        case .tempFile: "Geçici dosya"
        }
    }
}
