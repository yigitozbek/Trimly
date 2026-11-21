import Foundation

extension FileItem {
    /// Copy with a different folder histogram (descendant counts after a tree scan).
    func withHistogram(_ histogram: [String: Int]) -> FileItem {
        FileItem(
            url: url, name: name, fileExtension: fileExtension, kind: kind, sizeBytes: sizeBytes,
            createdAt: createdAt, modifiedAt: modifiedAt, utTypeIdentifier: utTypeIdentifier,
            spotlightDateAdded: spotlightDateAdded, spotlightWhereFroms: spotlightWhereFroms,
            spotlightTitle: spotlightTitle, spotlightAuthors: spotlightAuthors,
            spotlightContentCreationDate: spotlightContentCreationDate, folderSampleNames: folderSampleNames,
            folderExtensionHistogram: histogram, isLink: isLink, relativePath: relativePath,
            depth: depth, parentRelativePath: parentRelativePath
        )
    }
}
