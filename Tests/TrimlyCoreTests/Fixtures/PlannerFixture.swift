import Foundation
@testable import TrimlyCore

/// Temp root + data directory with a representative mix of files, shared by planner/executor/undo tests.
struct PlannerFixture {
    let root: URL
    let data: DataDirectory
    let store: PlanStore
    var settings: Settings

    init(standardFiles: Bool = true) throws {
        root = try TestFS.tempDir()
        data = DataDirectory(root: try TestFS.tempDir())
        store = PlanStore(directory: data)
        settings = Settings()
        // Fresh temp files may report Spotlight "date added = now"; keep the recent-change rule out of these tests.
        settings.recentMinutes = 0
        if standardFiles {
            try TestFS.file("Screenshot 2025-03-14 at 10.22.31.png", in: root)
            let invoice = try DocumentFactory.pdf(["Fatura No 123"], in: root, name: "download (3).pdf")
            try FileManager.default.setAttributes([.creationDate: Date.feb10Midday, .modificationDate: Date.twoDaysAgo], ofItemAtPath: invoice.path)
            try TestFS.file("cert.der", in: root)
            try TestFS.file("kimlik.pdf", in: root, contents: "TC kimlik no 12345678901")
            try TestFS.file("song.mp3", in: root)
            try TestFS.file(".DS_Store", in: root)
            let project = try TestFS.folder("myproj", in: root)
            try TestFS.folder(".git", in: project)
            let album = try TestFS.folder("Album", in: root)
            for i in 0..<8 { try TestFS.file("p\(i).jpg", in: album) }
        }
    }

    func planner(_ provider: (any LLMProvider)?, now: Date = Date()) -> Planner {
        Planner(settings: settings, store: store, provider: provider, now: { now })
    }

    static func result(_ folder: String, _ name: String = "Belge Ozeti", _ confidence: Double = 0.9, _ reason: String = "test") -> Result<ClassificationResult, any Error> {
        .success(ClassificationResult(targetFolder: folder, suggestedName: name, confidence: confidence, reason: reason))
    }
}
