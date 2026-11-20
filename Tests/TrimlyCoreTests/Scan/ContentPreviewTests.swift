import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct ContentPreviewTests {
    @Test func truncatesText() throws {
        let url = try TestFS.file("notes.txt", in: try TestFS.tempDir(), contents: String(repeating: "a", count: 3000))
        #expect(ContentPreview.text(for: url, maxCharacters: 1500, pdfPages: 1)?.count == 1500)
    }

    @Test func pdfRespectsPageLimit() throws {
        let url = try DocumentFactory.pdf(["Sayfa bir fatura", "Sayfa iki toplam"], in: try TestFS.tempDir())
        let one = try #require(ContentPreview.text(for: url, maxCharacters: 1500, pdfPages: 1))
        #expect(one.contains("Sayfa bir"))
        #expect(one.contains("Sayfa iki") == false)
        #expect(ContentPreview.text(for: url, maxCharacters: 4000, pdfPages: 2)?.contains("Sayfa iki") == true)
    }

    @Test func readsDocx() throws {
        let url = try DocumentFactory.attributed("Kira sözleşmesi metni", type: .officeOpenXML, in: try TestFS.tempDir(), name: "k.docx")
        #expect(ContentPreview.text(for: url, maxCharacters: 1500, pdfPages: 1)?.contains("Kira sözleşmesi") == true)
    }

    @Test func readsRTFWithTurkishCharacters() throws {
        let url = try DocumentFactory.attributed("Şirket sözleşmesi ğüı", type: .rtf, in: try TestFS.tempDir(), name: "s.rtf")
        #expect(ContentPreview.text(for: url, maxCharacters: 1500, pdfPages: 1)?.contains("Şirket sözleşmesi ğüı") == true)
    }

    @Test func binaryAndEmptyReturnNil() throws {
        let dir = try TestFS.tempDir()
        #expect(ContentPreview.text(for: try TestFS.file("x.png", in: dir), maxCharacters: 1500, pdfPages: 1) == nil)
        #expect(ContentPreview.text(for: try TestFS.file("e.txt", in: dir, contents: "  \n"), maxCharacters: 1500, pdfPages: 1) == nil)
    }
}
