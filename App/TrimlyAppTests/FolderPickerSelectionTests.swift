import Foundation
import Testing
@testable import TrimlyApp

struct FolderPickerSelectionTests {
    @Test func emptyUntilAnyChipSelected() {
        var selection = FolderPickerSelection()
        #expect(selection.isEmpty)
        #expect(selection.urls.isEmpty)
        selection.downloads = true
        #expect(selection.isEmpty == false)
        #expect(selection.urls == [URL.downloadsDirectory.standardizedFileURL])
    }

    @Test func urlsStableOrderDesktopDownloadsDocuments() {
        var selection = FolderPickerSelection(desktop: true, downloads: true, documents: true)
        #expect(selection.urls == [
            URL.desktopDirectory.standardizedFileURL,
            URL.downloadsDirectory.standardizedFileURL,
            URL.documentsDirectory.standardizedFileURL
        ])
    }
}
