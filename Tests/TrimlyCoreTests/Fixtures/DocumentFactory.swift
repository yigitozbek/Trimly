import AppKit
import CoreGraphics
import CoreText
import Foundation

enum DocumentFactory {
    struct CouldNotCreate: Error {}

    /// One PDF page per string, drawn as real text so PDFKit can extract it.
    static func pdf(_ pages: [String], in dir: URL, name: String = "doc.pdf") throws -> URL {
        let url = dir.appending(path: name)
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw CouldNotCreate()
        }
        for text in pages {
            context.beginPDFPage(nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 24)]))
            context.textPosition = CGPoint(x: 72, y: 700)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    static func attributed(_ text: String, type: NSAttributedString.DocumentType, in dir: URL, name: String) throws -> URL {
        let string = NSAttributedString(string: text)
        let data = try string.data(from: NSRange(location: 0, length: string.length), documentAttributes: [.documentType: type])
        let url = dir.appending(path: name)
        try data.write(to: url)
        return url
    }
}
