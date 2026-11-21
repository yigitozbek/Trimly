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

    func refresh() {
        do {
            let all = try RunLog.list(in: environment.directory)
            runs = limit.map { Array(all.prefix($0)) } ?? all
        } catch {
            errorMessage = UserMessage.text(for: error)
        }
    }

    func undo(runID: String) async {
        do {
            lastUndo = try await Undoer(directory: environment.directory).undo(runID: runID)
            errorMessage = nil
        } catch {
            errorMessage = UserMessage.text(for: error)
        }
        refresh()
    }
}
