import ArgumentParser
import Foundation
import TrimlyCore

struct UndoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "undo", abstract: "Bir uygulamayı geri alır (varsayılan: en son geri alınmamış olan).")

    @Argument(help: "İşlem kimliği (r-…).")
    var runID: String?

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            let summary = try await Undoer(directory: env.directory).undo(runID: runID)
            print("\(summary.runID): geri yüklenen \(summary.restored) · kaldırılan klasör \(summary.removedFolders) · atlanan \(summary.skipped.count)")
            summary.skipped.forEach { print("  atlandı: \($0.path) — \($0.reason)") }
        }
    }
}
