import Foundation

/// Deterministic default mode for a folder in a nested plan (never left to the LLM).
enum FolderModeDecider {
    /// Not descended → `keep` (moves as before). A pinned descendant (partial download, recent change, project…)
    /// → `distribute`. Otherwise `keep` when one category covers at least `distributeThreshold` of the files.
    static func mode(for folder: FileItem, descended: Bool, hasPinnedDescendant: Bool, settings: Settings) -> FolderMode {
        guard descended else {
            return .keep
        }
        if hasPinnedDescendant {
            return .distribute
        }
        var counts: [String: Int] = [:]
        for (ext, count) in folder.folderExtensionHistogram {
            let last = ext.split(separator: ".").last.map(String.init) ?? ext
            counts[DefaultRules.extensionMap[last]?.categoryID ?? "other", default: 0] += count
        }
        let total = counts.values.reduce(0, +)
        guard total > 0, let top = counts.values.max() else {
            return .keep
        }
        return Double(top) / Double(total) >= settings.distributeThreshold ? .keep : .distribute
    }
}
