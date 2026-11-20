import ArgumentParser
import Foundation
import TrimlyCore

struct GlobalOptions: ParsableArguments {
    @Option(name: .customLong("data-dir"), help: "Veri dizini (varsayılan: ~/Library/Application Support/Trimly).")
    var dataDir: String?

    /// Prepares the data directory, resolves interrupted runs and loads settings.
    func environment() throws -> CLIEnvironment {
        let directory = dataDir.map { DataDirectory(root: CLIEnvironment.absoluteURL($0)) } ?? .default
        try directory.ensureExists()
        try Recovery.recoverAll(in: directory)
        return CLIEnvironment(directory: directory, settings: try SettingsStore.load(from: directory))
    }
}
