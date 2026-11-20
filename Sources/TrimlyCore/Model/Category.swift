import Foundation

public struct Category: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    /// Folder name (plural), e.g. "Faturalar".
    public var folder: LocalizedText
    /// Tag used inside file names (singular), e.g. "Fatura".
    public var tag: LocalizedText

    public init(id: String, folder: LocalizedText, tag: LocalizedText) {
        self.id = id
        self.folder = folder
        self.tag = tag
    }
}
