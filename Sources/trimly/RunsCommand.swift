import ArgumentParser
import Foundation
import TrimlyCore

struct RunsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "runs", abstract: "Uygulanan işlemlerin geçmişini listeler.")

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            let runs = try RunLog.list(in: env.directory)
            guard runs.isEmpty == false else {
                print("Henüz uygulanmış işlem yok.")
                return
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            for run in runs {
                let state = run.undone ? "geri alındı" : "aktif"
                print("\(run.runID)  \(formatter.string(from: run.at))  taşınan \(run.moved)  etiket \(run.tagged)  \(state)  \(run.root)")
            }
        }
    }
}
