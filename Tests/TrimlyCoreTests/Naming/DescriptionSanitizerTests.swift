import Testing
@testable import TrimlyCore

struct DescriptionSanitizerTests {
    let invoice = ["Faturalar", "Fatura", "Invoices", "Invoice"]

    @Test func stripsExtensionAndDate() {
        #expect(DescriptionSanitizer.sanitize("Enerjisa Ocak 2025-01-31.pdf", originalExtension: "pdf", categoryTerms: invoice) == "Enerjisa-Ocak")
    }

    @Test func stripsLeadingCategoryTerm() {
        #expect(DescriptionSanitizer.sanitize("Fatura - Turkcell Ekim", originalExtension: "pdf", categoryTerms: invoice) == "Turkcell-Ekim")
    }

    @Test func stripsMultiWordTerm() {
        let terms = ["Ekran-Goruntuleri", "Ekran-Goruntusu", "Screenshots", "Screenshot"]
        #expect(DescriptionSanitizer.sanitize("ekran görüntüsü toplantı notu", originalExtension: "png", categoryTerms: terms) == "Toplanti-Notu")
    }

    @Test(arguments: ["Kira 14.03.2025", "Kira 20250314", "Kira 2025_03_14", "Kira Mart 2025", "Kira march 2025", "2025-03-14 Kira", "Kira_20250314", "Kira_20261028_0148"])
    func stripsDateFormats(_ raw: String) {
        #expect(DescriptionSanitizer.sanitize(raw, originalExtension: "pdf", categoryTerms: []) == "Kira")
    }

    @Test(.tags(.edgeCase)) func keepsNumbersThatAreNotDates() {
        #expect(DescriptionSanitizer.sanitize("Siparis 20123456", originalExtension: "pdf", categoryTerms: []) == "Siparis-20123456")
    }

    @Test func stripsFillerAndKnownExtensions() {
        #expect(DescriptionSanitizer.sanitize("yeni dosya kopya.docx.pdf", originalExtension: "pdf", categoryTerms: []) == nil)
        #expect(DescriptionSanitizer.sanitize("Rapor copy.PDF", originalExtension: "pdf", categoryTerms: []) == "Rapor")
    }

    @Test func tooShortReturnsNil() {
        #expect(DescriptionSanitizer.sanitize("a", originalExtension: "txt", categoryTerms: []) == nil)
        #expect(DescriptionSanitizer.sanitize("2025-03-14", originalExtension: "png", categoryTerms: []) == nil)
    }

    @Test func capsAt50() {
        let s = DescriptionSanitizer.sanitize(String(repeating: "uzun kelime ", count: 10), originalExtension: "pdf", categoryTerms: [])
        #expect((s?.count ?? 99) <= 50)
    }
}
