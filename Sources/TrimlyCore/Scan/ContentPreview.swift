import AppKit
import Foundation
import PDFKit

/// Local, in-process text preview for the LLM. Callers must never request it for critical items.
public enum ContentPreview {
    private static let plainTextExtensions: Set<String> = [
        "txt", "md", "markdown", "json", "geojson", "csv", "tsv", "xml", "yaml", "yml", "log", "html", "htm"
    ]
    private static let richTextTypes: [String: NSAttributedString.DocumentType] = [
        "rtf": .rtf, "docx": .officeOpenXML, "doc": .docFormat, "odt": .openDocument
    ]

    public static func text(for url: URL, maxCharacters: Int, pdfPages: Int) -> String? {
        let ext = url.pathExtension.lowercased()
        let raw: String? = if plainTextExtensions.contains(ext) {
            plainText(url, maxCharacters: maxCharacters)
        } else if ext == "pdf" {
            pdfText(url, pages: pdfPages)
        } else if let type = richTextTypes[ext] {
            try? NSAttributedString(url: url, options: [.documentType: type], documentAttributes: nil).string
        } else {
            nil
        }
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
            return nil
        }
        return String(trimmed.prefix(maxCharacters))
    }

    private static func plainText(_ url: URL, maxCharacters: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }
        // UTF-8 needs at most 4 bytes per character.
        guard let data = try? handle.read(upToCount: maxCharacters * 4) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func pdfText(_ url: URL, pages: Int) -> String? {
        guard let document = PDFDocument(url: url) else {
            return nil
        }
        let count = min(pages, document.pageCount)
        return (0..<count).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
    }
}
