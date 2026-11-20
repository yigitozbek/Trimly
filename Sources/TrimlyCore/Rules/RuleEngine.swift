import Foundation

/// Deterministic first pass: file-name patterns, then the extension map. Never calls the LLM.
public struct RuleEngine: Sendable {
    private static let folderMajority = 0.7
    private static let keywordCategories: Set<String> = ["documents", "images", "spreadsheets"]

    public init(settings: Settings) {}

    public func match(_ item: FileItem) -> RuleMatch {
        if item.kind == .folder {
            return folderMatch(item.folderExtensionHistogram)
        }
        let ext = item.fileExtension.split(separator: ".").last.map(String.init) ?? ""
        let mapped = extensionCategory(ext, item: item)
        let isImage = mapped?.categoryID == "images" || mapped?.categoryID == "photos"
        let isVideo = mapped?.categoryID == "videos"
        let name = Normalizer.ascii(item.name).lowercased()

        if isImage && name.contains(/^(screenshot|ekran resmi|ekran goruntusu)\b/) {
            return RuleMatch(categoryID: "screenshots", strength: .decisive, descriptionHint: timeHint(in: name))
        }
        if isVideo && name.contains(/^(screen recording|ekran kaydi)\b/) {
            return RuleMatch(categoryID: "screenRecordings", strength: .decisive, descriptionHint: timeHint(in: name))
        }
        if (isImage || isVideo) && name.contains(/^((img|pxl|dsc|dcim)_?\d+|whatsapp (image|video|gorsel))/) {
            return RuleMatch(categoryID: isVideo ? "videos" : "photos", strength: .decisive, descriptionHint: nil)
        }
        if mapped == nil || Self.keywordCategories.contains(mapped?.categoryID ?? "") {
            if name.contains(/fatura|invoice|e-arsiv|e-fatura|receipt|dekont/) {
                return RuleMatch(categoryID: "invoices", strength: .decisive, descriptionHint: nil)
            }
            if name.contains(/sozlesme|contract|agreement/) {
                return RuleMatch(categoryID: "contracts", strength: .decisive, descriptionHint: nil)
            }
        }
        if let mapped {
            return RuleMatch(categoryID: mapped.categoryID, strength: mapped.strength, descriptionHint: nil)
        }
        return RuleMatch(categoryID: "other", strength: .weak, descriptionHint: nil)
    }

    private func extensionCategory(_ ext: String, item: FileItem) -> (categoryID: String, strength: RuleStrength)? {
        if ext == "key" {
            let isKeynote = item.kind == .package || (item.utTypeIdentifier ?? "").contains("keynote")
            return (isKeynote ? "presentations" : "certificates", .decisive)
        }
        return DefaultRules.extensionMap[ext]
    }

    /// Folders are never decisive: one category must cover ≥ 70 % of the recognised files to become the guess.
    private func folderMatch(_ histogram: [String: Int]) -> RuleMatch {
        var counts: [String: Int] = [:]
        for (ext, count) in histogram {
            let last = ext.split(separator: ".").last.map(String.init) ?? ext
            if let category = DefaultRules.extensionMap[last]?.categoryID {
                counts[category, default: 0] += count
            }
        }
        let total = counts.values.reduce(0, +)
        if total > 0, let top = counts.max(by: { $0.value < $1.value }), Double(top.value) / Double(total) >= Self.folderMajority {
            return RuleMatch(categoryID: top.key, strength: .weak, descriptionHint: nil)
        }
        return RuleMatch(categoryID: "other", strength: .weak, descriptionHint: nil)
    }

    /// `HH-MM-SS` from the last `h.mm.ss` / `h:mm:ss` in the name.
    private func timeHint(in name: String) -> String? {
        guard let match = name.matches(of: /(\d{1,2})[.:](\d{2})[.:](\d{2})/).last,
              let hour = Int(match.output.1) else {
            return nil
        }
        return String(format: "%02d-%@-%@", hour, String(match.output.2), String(match.output.3))
    }
}
