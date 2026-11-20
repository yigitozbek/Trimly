import Testing
@testable import TrimlyCore

struct NormalizerTests {
    @Test func asciiFoldsTurkish() {
        #expect(Normalizer.ascii("çğıİöşüÇĞÖŞÜ") == "cgiIosuCGOSU")
    }

    @Test func asciiFoldsNFD() {
        #expect(Normalizer.ascii("s\u{0327}u\u{0308}") == "su")
        #expect(Normalizer.ascii("café") == "cafe")
    }

    @Test func slugTitleCasesAndCleans() {
        #expect(Normalizer.slug("sözleşme v3 final") == "Sozlesme-V3-Final")
        #expect(Normalizer.slug("  Enerjisa__Ocak!! ") == "Enerjisa-Ocak")
        #expect(Normalizer.slug("İSTANBUL ışık") == "ISTANBUL-Isik")
        #expect(Normalizer.slug("a---b") == "A-B")
    }

    @Test func slugCutsAtWordBoundary() {
        let s = Normalizer.slug(String(repeating: "kelime ", count: 20))
        #expect(s.count <= 50)
        #expect(s.hasSuffix("-") == false)
        #expect(s.split(separator: "-").allSatisfy { $0 == "Kelime" })
    }

    @Test func slugOfSymbolsIsEmpty() {
        #expect(Normalizer.slug("🔥🔥 !!") == "")
    }

    @Test func fullExtension() {
        #expect(Normalizer.fullExtension(of: "backup.TAR.GZ") == "tar.gz")
        #expect(Normalizer.fullExtension(of: "a.pdf") == "pdf")
        #expect(Normalizer.fullExtension(of: "Makefile") == "")
        #expect(Normalizer.fullExtension(of: "v1.2 notes") == "")
    }

    @Test func normalizedFileName() {
        #expect(Normalizer.normalizedFileName("Proje Dosyaları (Eski).ZIP", isFolder: false) == "Proje-Dosyalari-Eski.zip")
        #expect(Normalizer.normalizedFileName("Kişisel v1.2", isFolder: true) == "Kisisel-V1-2")
    }
}
