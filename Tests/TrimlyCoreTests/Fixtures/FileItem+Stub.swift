import Foundation
@testable import TrimlyCore

extension FileItem {
    static func stub(
        _ name: String,
        kind: EntryKind = .file,
        modifiedAt: Date = .twoDaysAgo,
        createdAt: Date? = .twoDaysAgo,
        dateAdded: Date? = nil,
        contentCreation: Date? = nil,
        utType: String? = nil,
        histogram: [String: Int] = [:],
        isLink: Bool = false,
        url: URL? = nil
    ) -> FileItem {
        FileItem(
            url: url ?? URL(filePath: "/tmp/trimly-stub").appending(path: name),
            name: name,
            fileExtension: (name as NSString).pathExtension.lowercased(),
            kind: kind,
            sizeBytes: kind == .file ? 1 : nil,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            utTypeIdentifier: utType,
            spotlightDateAdded: dateAdded,
            spotlightContentCreationDate: contentCreation,
            folderExtensionHistogram: histogram,
            isLink: isLink
        )
    }
}
