import Foundation
import Testing
@testable import TrimlyCore

struct OrganizedNameTests {
    let settings = Settings()

    @Test func trimlyNamedFileInsideItsCategoryFolderMatches() {
        let item = FileItem.stub("2025-02-10_Fatura_Enerjisa-Elektrik.pdf", depth: 1, parent: "Faturalar")
        #expect(OrganizedName.match(item, settings: settings) == OrganizedName.Match(categoryID: "invoices", description: "Enerjisa-Elektrik"))
    }

    @Test func yearFolderDepthStillUsesTheCategoryFolder() {
        let item = FileItem.stub("2025-02-10_Fatura_Enerjisa.pdf", depth: 2, parent: "Faturalar/2025")
        #expect(OrganizedName.match(item, settings: settings)?.categoryID == "invoices")
    }

    @Test(arguments: [
        ("download (3).pdf", 1, "Faturalar"),
        ("2025-02-10_Belge_Rapor.pdf", 1, "Faturalar"),
        ("2025-02-10_Fatura_Enerjisa.pdf", 0, ""),
        ("2025-02-10_Fatura_Enerjisa.pdf", 1, "Rastgele")
    ])
    func otherNamesOrLocationsDoNotMatch(name: String, depth: Int, parent: String) {
        let item = FileItem.stub(name, depth: depth, parent: parent.isEmpty ? nil : parent)
        #expect(OrganizedName.match(item, settings: settings) == nil)
    }

    @Test func folderInsideCategoryFolderMatchesWhenNameIsNormalized() {
        #expect(OrganizedName.match(.stub("Tatil-2024", kind: .folder, depth: 1, parent: "Fotograflar"), settings: settings)?.categoryID == "photos")
        #expect(OrganizedName.match(.stub("Tatil 2024", kind: .folder, depth: 1, parent: "Fotograflar"), settings: settings) == nil)
    }

    @Test func presetWithoutDateMatchesItsOwnFormat() {
        var settings = Settings()
        settings.namingPreset = .categoryDescription
        let item = FileItem.stub("Fatura_Enerjisa.pdf", depth: 1, parent: "Faturalar")
        #expect(OrganizedName.match(item, settings: settings)?.description == "Enerjisa")
    }
}
