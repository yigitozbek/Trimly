import Testing
@testable import TrimlyCore

struct NamingTemplateTests {
    func name(_ preset: NamingPreset, ext: String = "pdf", original: String = "download (3).PDF") -> String {
        NamingTemplate.fileName(preset: preset, day: "2025-02-10", categoryTag: "Fatura", description: "Enerjisa-Ocak", originalName: original, fileExtension: ext)
    }

    @Test func presets() {
        #expect(name(.dateCategoryDescription) == "2025-02-10_Fatura_Enerjisa-Ocak.pdf")
        #expect(name(.categoryDescription) == "Fatura_Enerjisa-Ocak.pdf")
        #expect(name(.dateDescription) == "2025-02-10_Enerjisa-Ocak.pdf")
        #expect(name(.originalNormalized) == "Download-3.pdf")
        #expect(name(.keepOriginal) == "download (3).PDF")
    }

    @Test(.tags(.edgeCase)) func compoundExtension() {
        #expect(NamingTemplate.fileName(preset: .dateCategoryDescription, day: "2025-02-10", categoryTag: "Arsiv", description: "Yedek", originalName: "yedek.tar.gz", fileExtension: "tar.gz") == "2025-02-10_Arsiv_Yedek.tar.gz")
    }

    @Test func noExtension() {
        #expect(name(.dateCategoryDescription, ext: "", original: "Makefile").hasSuffix("_Enerjisa-Ocak"))
    }

    @Test func upperCaseExtensionIsLowered() {
        #expect(name(.dateCategoryDescription, ext: "PDF") == "2025-02-10_Fatura_Enerjisa-Ocak.pdf")
    }

    @Test func folderNames() {
        #expect(NamingTemplate.folderName(preset: .dateCategoryDescription, originalName: "Tatil Fotoğrafları") == "Tatil-Fotograflari")
        #expect(NamingTemplate.folderName(preset: .keepOriginal, originalName: "Tatil Fotoğrafları") == "Tatil Fotoğrafları")
    }
}
