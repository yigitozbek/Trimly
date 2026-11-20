import Testing
@testable import TrimlyCore

struct RuleEngineTests {
    let engine = RuleEngine(settings: Settings())

    func match(_ name: String, utType: String? = nil) -> RuleMatch {
        engine.match(.stub(name, utType: utType))
    }

    @Test func screenshotsAndRecordings() {
        #expect(match("Screenshot 2025-03-14 at 10.22.31.png") == RuleMatch(categoryID: "screenshots", strength: .decisive, descriptionHint: "10-22-31"))
        #expect(match("Ekran Resmi 2025-03-14 10.22.31.png").descriptionHint == "10-22-31")
        #expect(match("Ekran Görüntüsü 2025-03-14 9.05.07.png").descriptionHint == "09-05-07")
        #expect(match("Ekran Kaydı 2025-03-14 10.22.31.mov").categoryID == "screenRecordings")
    }

    @Test func cameraNames() {
        #expect(match("IMG_4821.HEIC") == RuleMatch(categoryID: "photos", strength: .decisive, descriptionHint: nil))
        #expect(match("IMG_4822.MOV").categoryID == "videos")
        #expect(match("PXL_20240101_123.jpg").categoryID == "photos")
        #expect(match("WhatsApp Image 2024-05-01 at 12.00.00.jpeg").categoryID == "photos")
    }

    @Test func keywordRules() {
        #expect(match("e-Arşiv Fatura 123.pdf") == RuleMatch(categoryID: "invoices", strength: .decisive, descriptionHint: nil))
        #expect(match("Kira Sözleşmesi.docx").categoryID == "contracts")
        #expect(match("fatura-ozet.mp4").categoryID == "videos")
    }

    @Test(arguments: [("song.mp3", "audio"), ("setup.dmg", "installers"), ("font.otf", "fonts"), ("design.pxd", "design"), ("map.geojson", "data"), ("main.swift", "code"), ("book.epub", "books"), ("talep.udf", "officialDocs"), ("cert.der", "certificates"), ("yedek.tar.gz", "archives")])
    func extensionDecisive(name: String, category: String) {
        #expect(match(name) == RuleMatch(categoryID: category, strength: .decisive, descriptionHint: nil))
    }

    @Test(arguments: [("document.pdf", "documents"), ("export.json", "data"), ("list.csv", "spreadsheets"), ("files.zip", "archives"), ("tool.jar", "installers"), ("notes.md", "documents"), ("thing.xyz", "other")])
    func extensionWeak(name: String, category: String) {
        #expect(match(name) == RuleMatch(categoryID: category, strength: .weak, descriptionHint: nil))
    }

    @Test func keynoteVersusKey() {
        #expect(match("sunum.key", utType: "com.apple.iwork.keynote.key").categoryID == "presentations")
        #expect(match("server.key").categoryID == "certificates")
    }

    @Test func folders() {
        #expect(engine.match(.stub("A", kind: .folder, histogram: ["jpg": 8, "txt": 1])) == RuleMatch(categoryID: "images", strength: .weak, descriptionHint: nil))
        #expect(engine.match(.stub("B", kind: .folder, histogram: ["jpg": 3, "pdf": 3])).categoryID == "other")
        #expect(engine.match(.stub("C", kind: .folder)).strength == .weak)
        #expect(engine.match(.stub("Screenshot klasoru", kind: .folder, histogram: ["png": 5])).strength == .weak)
    }

    @Test func everyMappedExtensionIsKnown() {
        #expect(Set(DefaultRules.extensionMap.keys).isSubset(of: KnownExtensions.all))
    }
}
