import Foundation
import Observation
import TrimlyCore

/// Applied runs and their undo; the start window shows the newest five, the history window all of them.
@MainActor
@Observable
final class RunsModel {
    private let environment: AppEnvironment
    private let limit: Int?
    private(set) var runs: [RunInfo] = []
    private(set) var lastUndo: UndoSummary?
    private(set) var errorMessage: String?

    init(environment: AppEnvironment, limit: Int?) {
        self.environment = environment
        self.limit = limit
    }

    func refresh() async {
        do {
            let all = try await Self.list(environment.directory)
            runs = limit.map { Array(all.prefix($0)) } ?? all
        } catch {
            errorMessage = UserMessage.text(for: error)
        }
    }

    /// Journals accumulate; parse them off the main actor.
    @concurrent
    private static func list(_ directory: DataDirectory) async throws -> [RunInfo] {
        try RunLog.list(in: directory)
    }

    func undo(runID: String) async {
        do {
            lastUndo = try await Undoer(directory: environment.directory).undo(runID: runID)
            errorMessage = nil
        } catch {
            errorMessage = UserMessage.text(for: error)
        }
        await refresh()
    }
}
