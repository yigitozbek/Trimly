import Foundation
import Testing
@testable import TrimlyCore

struct DateResolverTests {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }

    func day(_ name: String) -> String? {
        DateResolver.dateFromName(name, calendar: cal).map { DateResolver.dayString($0, calendar: cal) }
    }

    func iso(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    @Test func dateFromNamePatterns() {
        #expect(day("Screenshot 2025-03-14 at 10.22.31.png") == "2025-03-14")
        #expect(day("IMG_20240812_101500.jpg") == "2024-08-12")
        #expect(day("fatura_14.03.2025.pdf") == "2025-03-14")
        #expect(day("scan 2025_01_02.pdf") == "2025-01-02")
        #expect(day("order-99999999.pdf") == nil)
        #expect(day("v2025-13-40.txt") == nil)
        #expect(day("12345678.pdf") == nil)
    }

    @Test func resolvePriority() {
        let all = FileItem.stub("rapor 2025-01-05.pdf", modifiedAt: iso("2025-04-01T10:00:00Z"), createdAt: iso("2025-03-01T10:00:00Z"), contentCreation: iso("2025-02-01T10:00:00Z"))
        #expect(DateResolver.dayString(DateResolver.resolve(all, calendar: cal), calendar: cal) == "2025-01-05")
        let noName = FileItem.stub("rapor.pdf", modifiedAt: iso("2025-04-01T10:00:00Z"), createdAt: iso("2025-03-01T10:00:00Z"), contentCreation: iso("2025-02-01T10:00:00Z"))
        #expect(DateResolver.dayString(DateResolver.resolve(noName, calendar: cal), calendar: cal) == "2025-02-01")
        let created = FileItem.stub("rapor.pdf", modifiedAt: iso("2025-04-01T10:00:00Z"), createdAt: iso("2025-03-01T10:00:00Z"))
        #expect(DateResolver.dayString(DateResolver.resolve(created, calendar: cal), calendar: cal) == "2025-03-01")
        let modifiedOnly = FileItem.stub("rapor.pdf", modifiedAt: iso("2025-04-01T10:00:00Z"), createdAt: nil)
        #expect(DateResolver.dayString(DateResolver.resolve(modifiedOnly, calendar: cal), calendar: cal) == "2025-04-01")
    }
}
