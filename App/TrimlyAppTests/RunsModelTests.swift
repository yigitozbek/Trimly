import Foundation
import Testing
import TrimlyCore
@testable import TrimlyApp

@MainActor
@Suite(.tags(.fileSystem))
struct RunsModelTests {
    @Test func limitsToNewestRuns() async throws {
        let fixture = try AppFixture.empty()
        let base = Date()
        var roots: [URL] = []
        for index in 0..<6 {
            let root = try TestFS.tempDir()
            try TestFS.file("IMG_000\(index).HEIC", in: root)
            try await fixture.applyOnce(root: root, now: base.addingTimeInterval(Double(index)))
            roots.append(root)
        }
        let model = RunsModel(environment: fixture.environment(), limit: 5)
        model.refresh()
        #expect(model.runs.count == 5)
        #expect(model.runs.first?.root == roots[5].path)
    }

    @Test func undoRestoresAndRefreshes() async throws {
        let fixture = try AppFixture.empty()
        try TestFS.file("IMG_0001.HEIC", in: fixture.root)
        try await fixture.applyOnce()
        let model = RunsModel(environment: fixture.environment(), limit: nil)
        model.refresh()
        let runID = try #require(model.runs.first?.runID)
        await model.undo(runID: runID)
        #expect(model.lastUndo?.restored == 1)
        #expect(model.runs.first?.undone == true)
        #expect(FileManager.default.fileExists(atPath: fixture.root.appending(path: "IMG_0001.HEIC").path))
    }

    @Test func undoErrorBecomesMessage() async throws {
        let model = RunsModel(environment: try AppFixture.empty().environment(), limit: nil)
        await model.undo(runID: "r-yok")
        #expect(model.errorMessage == "İşlem bulunamadı: r-yok")
    }
}
