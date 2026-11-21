import Foundation
import TrimlyCore
@testable import TrimlyApp

/// Temporary root + data directory and an `AppEnvironment` pointing at them. Never touches real user folders.
struct AppFixture {
    let root: URL
    let data: DataDirectory

    static func empty() throws -> AppFixture {
        let fixture = AppFixture(root: try TestFS.tempDir(), data: DataDirectory(root: try TestFS.tempDir()))
        try fixture.writeSettings { settings in
            settings.recentMinutes = 0
            settings.llmEnabled = false
        }
        return fixture
    }

    static func standard() throws -> AppFixture {
        let fixture = try empty()
        try TestFS.file("Screenshot 2025-03-14 at 10.22.31.png", in: fixture.root)
        try TestFS.file("download (3).pdf", in: fixture.root, contents: "Fatura No 123")
        try TestFS.file("kimlik.pdf", in: fixture.root)
        try TestFS.file("song.mp3", in: fixture.root)
        try TestFS.file(".DS_Store", in: fixture.root)
        let album = try TestFS.folder("Album", in: fixture.root)
        for index in 0..<3 {
            try TestFS.file("p\(index).jpg", in: album)
        }
        return fixture
    }

    func writeSettings(_ change: (inout Settings) -> Void) throws {
        var settings = (try? SettingsStore.load(from: data)) ?? Settings()
        change(&settings)
        try SettingsStore.save(settings, to: data)
    }

    func environment(provider: (any LLMProvider)? = nil, now: Date = Date()) -> AppEnvironment {
        AppEnvironment(directory: data, makeProvider: { _ in provider ?? UnreachableProvider() }, now: { now })
    }

    /// Plans (rules only) and applies `root` (default: the fixture root); returns the run.
    @discardableResult
    func applyOnce(root: URL? = nil, now: Date = Date()) async throws -> RunSummary {
        let settings = (try? SettingsStore.load(from: data)) ?? Settings()
        let planner = Planner(settings: settings, store: PlanStore(directory: data), provider: nil, now: { now })
        let plan = try await planner.makePlan(root: root ?? self.root, useLLM: false)
        return try await Executor(directory: data, now: { now }).apply(planID: plan.id)
    }
}

extension Date {
    /// 2025-02-10 12:00 local time — midday, so day strings do not depend on the time zone.
    static var feb10Midday: Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 10, hour: 12))!
    }
}
