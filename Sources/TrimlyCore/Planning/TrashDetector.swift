import CryptoKit
import Foundation

/// Marks eligible plan items with at most one `TrashReason`. Never touches critical, covered, skipped, or folder items.
public enum TrashDetector {
    private static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "iso", "exe", "msi"]
    private static let partialExtensions: Set<String> = ["crdownload", "part", "download", "opdownload"]

    public static func apply(_ plan: inout Plan, files: [FileItem], settings: Settings, now: Date) {
        let byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.relativePath, $0) })
        var reasons: [String: TrashReason] = [:]

        for item in plan.items {
            guard item.covered == false,
                  item.status != .skipped,
                  item.kind != .folder,
                  item.critical == false,
                  let file = byPath[item.relativePath] else {
                continue
            }
            if let reason = singleReason(for: file, settings: settings, now: now) {
                reasons[item.relativePath] = reason
            }
        }

        if settings.trashDuplicates {
            for (path, reason) in duplicates(among: plan.items, files: byPath, already: reasons) {
                reasons[path] = reason
            }
        }

        for index in plan.items.indices {
            plan.items[index].trashReason = reasons[plan.items[index].relativePath]
        }
    }

    private static func singleReason(for file: FileItem, settings: Settings, now: Date) -> TrashReason? {
        let ext = file.fileExtension.split(separator: ".").last.map(String.init)?.lowercased() ?? ""
        if settings.trashTempFiles, isTempName(file.name, extension: ext) {
            return .tempFile
        }
        if settings.trashEmptyFiles, file.sizeBytes == 0 {
            return .emptyFile
        }
        if settings.trashPartialDownloadAgeDays >= 0, Self.partialExtensions.contains(ext),
           let age = ageDate(of: file), now.timeIntervalSince(age) >= Double(settings.trashPartialDownloadAgeDays) * 86_400 {
            return .stalePartialDownload
        }
        if Self.installerExtensions.contains(ext),
           let age = ageDate(of: file),
           now.timeIntervalSince(age) >= Double(settings.trashInstallerAgeDays) * 86_400 {
            return .oldInstaller(days: settings.trashInstallerAgeDays)
        }
        return nil
    }

    private static func duplicates(
        among items: [PlanItem],
        files: [String: FileItem],
        already: [String: TrashReason]
    ) -> [String: TrashReason] {
        let candidates = items.filter {
            $0.covered == false && $0.status != .skipped && $0.kind != .folder && $0.critical == false
                && already[$0.relativePath] == nil
                && (files[$0.relativePath]?.sizeBytes ?? 0) > 0
        }
        var bySize: [Int64: [PlanItem]] = [:]
        for item in candidates {
            guard let size = files[item.relativePath]?.sizeBytes else { continue }
            bySize[size, default: []].append(item)
        }
        var found: [String: TrashReason] = [:]
        for group in bySize.values where group.count > 1 {
            var hashToItems: [String: [PlanItem]] = [:]
            for item in group {
                guard let file = files[item.relativePath], let digest = try? sha256(of: file.url) else { continue }
                hashToItems[digest, default: []].append(item)
            }
            for peers in hashToItems.values where peers.count > 1 {
                let original = pickOriginal(peers, files: files)
                for peer in peers where peer.relativePath != original.relativePath {
                    found[peer.relativePath] = .duplicate(of: original.relativePath)
                }
            }
        }
        return found
    }

    /// Original = shortest name without a copy suffix; ties → oldest.
    static func pickOriginal(_ items: [PlanItem], files: [String: FileItem]) -> PlanItem {
        items.sorted { lhs, rhs in
            let lCopy = isCopyName(lhs.name)
            let rCopy = isCopyName(rhs.name)
            if lCopy != rCopy { return lCopy == false }
            if lhs.name.count != rhs.name.count { return lhs.name.count < rhs.name.count }
            let lAge = files[lhs.relativePath].flatMap(ageDate) ?? .distantFuture
            let rAge = files[rhs.relativePath].flatMap(ageDate) ?? .distantFuture
            if lAge != rAge { return lAge < rAge }
            return lhs.relativePath < rhs.relativePath
        }.first!
    }

    static func isCopyName(_ name: String) -> Bool {
        let base = (name as NSString).deletingPathExtension
        if base.range(of: #" \(\d+\)$"#, options: .regularExpression) != nil { return true }
        let lower = base.lowercased()
        return lower.hasSuffix(" kopya") || lower.hasSuffix(" copy")
    }

    static func isTempName(_ name: String, extension ext: String) -> Bool {
        ext == "tmp" || name.hasPrefix("~$") || name.caseInsensitiveCompare("Thumbs.db") == .orderedSame
    }

    static func ageDate(of file: FileItem) -> Date? {
        file.spotlightDateAdded ?? file.createdAt ?? file.modifiedAt
    }

    static func sha256(of url: URL) throws -> String {
        var hasher = SHA256()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        while true {
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
