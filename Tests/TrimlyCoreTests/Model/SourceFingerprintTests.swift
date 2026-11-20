import Foundation
import Testing
@testable import TrimlyCore

struct SourceFingerprintTests {
    let base = Date(timeIntervalSince1970: 1_700_000_000.4)

    @Test func subSecondDriftMatches() {
        #expect(SourceFingerprint(size: 5, modifiedAt: base).matches(.init(size: 5, modifiedAt: base.addingTimeInterval(0.6))))
    }

    @Test func sizeOrSecondChangeDoesNotMatch() {
        #expect(SourceFingerprint(size: 5, modifiedAt: base).matches(.init(size: 6, modifiedAt: base)) == false)
        #expect(SourceFingerprint(size: 5, modifiedAt: base).matches(.init(size: 5, modifiedAt: base.addingTimeInterval(1.0))) == false)
    }

    @Test func directoriesOnlyNeedToExist() {
        #expect(SourceFingerprint(size: nil, modifiedAt: base).matches(.init(size: nil, modifiedAt: base.addingTimeInterval(500))))
    }

    @Test func readReturnsNilForMissingFile() throws {
        #expect(SourceFingerprint.read(from: try TestFS.tempDir().appending(path: "yok")) == nil)
    }

    @Test func readReportsSizeForFilesAndNilForDirectories() throws {
        let dir = try TestFS.tempDir()
        let file = try TestFS.file("a.txt", in: dir, contents: "hello")
        #expect(SourceFingerprint.read(from: file)?.size == 5)
        #expect(SourceFingerprint.read(from: dir)?.size == nil)
    }
}
