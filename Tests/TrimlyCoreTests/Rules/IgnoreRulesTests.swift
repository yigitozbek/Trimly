import Foundation
import Testing
@testable import TrimlyCore

struct IgnoreRulesTests {
    let now = Date()
    var rules: IgnoreRules { IgnoreRules(settings: Settings(), now: now) }

    @Test func systemAndHidden() {
        #expect(rules.skipReason(for: .stub(".DS_Store")) == "Sistem dosyası")
        #expect(rules.skipReason(for: .stub(".localized")) == "Sistem dosyası")
        #expect(rules.skipReason(for: .stub(".secret")) == "Gizli dosya")
    }

    @Test func appsAndLinks() {
        #expect(rules.skipReason(for: .stub("Foo.app", kind: .package)) == "Uygulama paketi")
        #expect(rules.skipReason(for: .stub("kisayol", isLink: true)) == "Kısayol veya sembolik bağ")
    }

    @Test(arguments: ["big.zip.crdownload", "x.part", "y.download", "z.opdownload"])
    func partialDownloads(_ name: String) {
        #expect(rules.skipReason(for: .stub(name)) == "Yarım indirme")
    }

    @Test(.tags(.edgeCase)) func recentUsesNewestOfDates() {
        #expect(rules.skipReason(for: .stub("a.pdf", modifiedAt: now.addingTimeInterval(-600))) == "Son 60 dakikada değişti")
        #expect(rules.skipReason(for: .stub("b.pdf", dateAdded: now.addingTimeInterval(-300))) == "Son 60 dakikada değişti")
        #expect(rules.skipReason(for: .stub("c.pdf", createdAt: now.addingTimeInterval(-300))) == "Son 60 dakikada değişti")
        #expect(rules.skipReason(for: .stub("old.pdf")) == nil)
    }

    @Test(.tags(.fileSystem)) func projectAndBuildFolders() throws {
        let root = try TestFS.tempDir()
        let project = try TestFS.folder("myproj", in: root)
        try TestFS.folder(".git", in: project)
        #expect(rules.skipReason(for: .stub("myproj", kind: .folder, url: project)) == "Proje klasörü (.git)")
        #expect(rules.skipReason(for: .stub("ios", kind: .folder, histogram: ["xcodeproj": 1])) == "Proje klasörü (*.xcodeproj)")
        #expect(rules.skipReason(for: .stub("node_modules", kind: .folder)) == "Build/çıktı klasörü")
        #expect(rules.skipReason(for: .stub("DerivedData", kind: .folder)) == "Build/çıktı klasörü")
    }

    @Test(.tags(.fileSystem)) func plainFolderIsNotSkipped() throws {
        let root = try TestFS.tempDir()
        let album = try TestFS.folder("Album", in: root)
        try TestFS.file("a.jpg", in: album)
        #expect(rules.skipReason(for: .stub("Album", kind: .folder, histogram: ["jpg": 1], url: album)) == nil)
    }

    @Test func categoryFoldersAndGlobs() {
        #expect(rules.skipReason(for: .stub("Faturalar", kind: .folder)) == "Trimly kategori klasörü")
        #expect(rules.skipReason(for: .stub("invoices", kind: .folder)) == "Trimly kategori klasörü")
        #expect(rules.skipReason(for: .stub("Faturalar")) == nil)
        #expect(rules.skipReason(for: .stub("Fotoğraflar.photoslibrary", kind: .package)) == "Hariç tutma listesi")
        var settings = Settings()
        settings.ignoreGlobs = ["*.tmp"]
        #expect(IgnoreRules(settings: settings, now: now).skipReason(for: .stub("x.TMP")) == "Hariç tutma listesi")
    }
}
