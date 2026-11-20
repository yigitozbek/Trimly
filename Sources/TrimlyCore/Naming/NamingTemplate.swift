import Foundation

public enum NamingTemplate {
    /// Builds the new file name for the selected preset. `description` must already be sanitized and normalized.
    public static func fileName(
        preset: NamingPreset,
        day: String,
        categoryTag: String,
        description: String,
        originalName: String,
        fileExtension: String
    ) -> String {
        let stem: String
        switch preset {
        case .dateCategoryDescription:
            stem = "\(day)_\(categoryTag)_\(description)"
        case .categoryDescription:
            stem = "\(categoryTag)_\(description)"
        case .dateDescription:
            stem = "\(day)_\(description)"
        case .originalNormalized:
            return Normalizer.normalizedFileName(originalName, isFolder: false)
        case .keepOriginal:
            return originalName
        }
        let ext = fileExtension.lowercased()
        return ext.isEmpty ? stem : "\(stem).\(ext)"
    }

    /// Folders move as a unit and are only normalized, never templated.
    public static func folderName(preset: NamingPreset, originalName: String) -> String {
        preset == .keepOriginal ? originalName : Normalizer.normalizedFileName(originalName, isFolder: true)
    }
}
