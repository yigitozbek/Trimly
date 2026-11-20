import Foundation

/// Decides which scanned items are never touched. Returns a Turkish, user-facing reason or `nil`.
public struct IgnoreRules: Sendable {
    private static let systemFiles: Set<String> = [".DS_Store", ".localized"]
    private static let partialDownloadExtensions: Set<String> = ["crdownload", "part", "download", "opdownload"]

    private let settings: Settings
    private let now: Date
    private let categoryFolderNames: Set<String>
    private let projectFolderNames: Set<String>

    public init(settings: Settings, now: Date) {
        self.settings = settings
        self.now = now
        self.categoryFolderNames = settings.allCategoryFolderNames
        self.projectFolderNames = Set(settings.projectFolderNames.map { $0.lowercased() })
    }

    public func skipReason(for item: FileItem) -> String? {
        let lastExtension = item.fileExtension.split(separator: ".").last.map(String.init) ?? ""
        let isFolder = item.kind == .folder

        if item.isLink {
            return "Kısayol veya sembolik bağ"
        }
        if Self.systemFiles.contains(item.name) {
            return "Sistem dosyası"
        }
        if settings.ignoreHidden && item.name.hasPrefix(".") {
            return "Gizli dosya"
        }
        if settings.ignoreGlobs.contains(where: { fnmatch($0, item.name, FNM_CASEFOLD) == 0 }) {
            return "Hariç tutma listesi"
        }
        if settings.ignoreApps && lastExtension == "app" {
            return "Uygulama paketi"
        }
        if Self.partialDownloadExtensions.contains(lastExtension) {
            return "Yarım indirme"
        }
        if isFolder && categoryFolderNames.contains(item.name.lowercased()) {
            return "Trimly kategori klasörü"
        }
        if isFolder && projectFolderNames.contains(item.name.lowercased()) {
            return "Build/çıktı klasörü"
        }
        if isFolder, let marker = projectMarker(in: item) {
            return "Proje klasörü (\(marker))"
        }
        if isRecent(item) {
            return "Son \(settings.recentMinutes) dakikada değişti"
        }
        return nil
    }

    private func projectMarker(in item: FileItem) -> String? {
        settings.projectMarkers.first { marker in
            if marker.hasPrefix("*.") {
                return item.folderExtensionHistogram[String(marker.dropFirst(2)).lowercased(), default: 0] > 0
            }
            return FileManager.default.fileExists(atPath: item.url.appending(path: marker).path)
        }
    }

    /// Uses the newest of modification, creation and Spotlight "date added": a fresh download may keep an old server mtime.
    private func isRecent(_ item: FileItem) -> Bool {
        guard let newest = [item.modifiedAt, item.createdAt, item.spotlightDateAdded].compactMap({ $0 }).max() else {
            return false
        }
        return newest > now.addingTimeInterval(-Double(settings.recentMinutes) * 60)
    }
}
