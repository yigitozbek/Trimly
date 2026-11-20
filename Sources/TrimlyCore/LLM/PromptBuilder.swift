import Foundation

public enum PromptBuilder {
    public static let systemPrompt = """
    Sen bir dosya düzenleme asistanısın. Sana tek bir dosya ya da klasör hakkında bilgi verilecek.
    Görevin onu hangi klasöre koymak gerektiğine karar vermek ve kısa bir açıklama önermek.

    Kurallar:
    - target_folder YALNIZCA "İzin verilen klasörler" listesindeki adlardan biri olabilir.
    - suggested_name 2-6 kelimelik kısa bir açıklamadır. İçine tarih, uzantı veya klasör/kategori adı YAZMA.
    - confidence 0 ile 1 arasında dürüst bir güven değeridir; emin değilsen 0.5'in altında ver.
    - reason Türkçe ve en fazla 160 karakterdir.
    - Yalnızca istenen JSON nesnesini döndür.
    """

    public static func userMessage(_ r: ClassificationRequest) -> String {
        var lines: [String] = ["Ad: \(r.name)"]
        if r.fileExtension.isEmpty == false { lines.append("Uzantı: \(r.fileExtension)") }
        lines.append("Tür: \(kindName(r.kind))")
        if let size = r.sizeBytes { lines.append("Boyut: \(size) bayt") }
        if let created = r.createdAt { lines.append("Oluşturulma: \(day(created))") }
        if let modified = r.modifiedAt { lines.append("Değiştirilme: \(day(modified))") }
        if let utType = r.utType { lines.append("UTType: \(utType)") }
        if let host = r.sourceHost { lines.append("İndirme kaynağı: \(host)") }
        if let title = r.spotlightTitle { lines.append("Belge başlığı: \(title)") }
        if r.spotlightAuthors.isEmpty == false { lines.append("Yazar: \(r.spotlightAuthors.joined(separator: ", "))") }
        if let hint = r.ruleHintCategoryFolder { lines.append("Kural tahmini: \(hint)") }
        if r.folderSampleNames.isEmpty == false { lines.append("Klasör içeriğinden örnekler: \(r.folderSampleNames.joined(separator: ", "))") }
        lines.append("İzin verilen klasörler: \(r.allowedFolders.joined(separator: ", "))")
        if let preview = r.contentPreview {
            lines.append("İçerik önizlemesi:\n\"\"\"\n\(preview)\n\"\"\"")
        }
        return lines.joined(separator: "\n")
    }

    private static func kindName(_ kind: EntryKind) -> String {
        switch kind {
        case .file: "dosya"
        case .folder: "klasör"
        case .package: "paket"
        }
    }

    private static func day(_ date: Date) -> String {
        DateResolver.dayString(date)
    }
}
