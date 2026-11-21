import Testing
@testable import TrimlyCore

struct PromptBuilderTests {
    func request(preview: String?) -> ClassificationRequest {
        ClassificationRequest(
            name: "download (3).pdf", fileExtension: "pdf", kind: .file, sizeBytes: 1, createdAt: nil, modifiedAt: nil,
            utType: nil, sourceHost: "www.enerjisa.com.tr/fatura", spotlightTitle: nil, spotlightAuthors: [],
            ruleHintCategoryFolder: "Belgeler", folderSampleNames: [], contentPreview: preview,
            allowedFolders: ["Belgeler", "Faturalar", "Diger"]
        )
    }

    @Test func previewSectionOnlyWhenPresent() {
        #expect(PromptBuilder.userMessage(request(preview: nil)).contains("İçerik önizlemesi") == false)
        let message = PromptBuilder.userMessage(request(preview: "Fatura No 123"))
        #expect(message.contains("İçerik önizlemesi") && message.contains("Fatura No 123"))
    }

    @Test func sourceHostDropsQuery() {
        #expect(ClassificationRequest.sourceHost(from: ["https://www.enerjisa.com.tr/fatura/indir?token=abc"]) == "www.enerjisa.com.tr/fatura/indir")
        #expect(ClassificationRequest.sourceHost(from: []) == nil)
    }

    @Test func listsAllowedFoldersAndContext() {
        let message = PromptBuilder.userMessage(request(preview: nil))
        #expect(["Belgeler", "Faturalar", "Diger", "download (3).pdf", "www.enerjisa.com.tr/fatura"].allSatisfy(message.contains))
    }

    @Test func nestedItemsCarryTheirLocation() {
        var request = request(preview: nil)
        request.relativePath = "Rastgele/alt/fatura.pdf"
        #expect(PromptBuilder.userMessage(request).contains("Konum: Rastgele/alt/"))
        request.relativePath = nil
        #expect(PromptBuilder.userMessage(request).contains("Konum:") == false)
    }
}
