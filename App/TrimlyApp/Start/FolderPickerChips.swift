import Foundation

/// Which well-known user folders are selected on the start screen (not the whole disk).
struct FolderPickerSelection: Equatable {
    var desktop = false
    var downloads = false
    var documents = false

    var isEmpty: Bool {
        desktop == false && downloads == false && documents == false
    }

    /// Resolved folder URLs in a stable order: Desktop → Downloads → Documents.
    var urls: [URL] {
        var result: [URL] = []
        if desktop { result.append(URL.desktopDirectory.standardizedFileURL) }
        if downloads { result.append(URL.downloadsDirectory.standardizedFileURL) }
        if documents { result.append(URL.documentsDirectory.standardizedFileURL) }
        return result
    }
}
