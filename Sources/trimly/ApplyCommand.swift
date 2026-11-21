import ArgumentParser
import Foundation
import TrimlyCore

struct ApplyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply", abstract: "Onaylı öğeleri journal'a yazarak taşır; her işlem geri alınabilir.")

    @Argument(help: "Plan kimliği.")
    var planID: String

    @Flag(help: "Son onayı sormadan uygula.")
    var yes = false

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            let plan = try env.store.load(id: planID)
            switch plan.state {
            case .applied: throw ExecutionError.alreadyApplied
            case .inProgress: throw ExecutionError.notReady
            case .ready: break
            }
            let approved = plan.items.filter { $0.approved && $0.status != .skipped && $0.target != nil }
            guard approved.isEmpty == false else {
                print("Onaylı öğe yok; hiçbir şey taşınmadı.")
                return
            }
            print("\(approved.count) öğe taşınacak.")
            let critical = approved.filter(\.critical)
            if critical.isEmpty == false {
                print("Elle onaylanmış kritik öğeler:")
                critical.forEach { print("  🔒 \($0.name) → \($0.target.map { Output.relative($0, to: plan.root) } ?? "—")") }
            }
            if yes == false {
                print("Uygulansın mı? [e/H] ", terminator: "")
                let answer = (readLine() ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                guard ["e", "evet", "y", "yes"].contains(answer) else {
                    print("İptal edildi.")
                    return
                }
            }
            let summary = try await Executor(directory: env.directory).apply(planID: planID)
            print("Taşınan: \(summary.moved) · Atlanan: \(summary.skipped.count) · Hatalı: \(summary.failed.count)")
            summary.skipped.forEach { print("  atlandı: \($0.path) — \($0.reason)") }
            summary.failed.forEach { print("  hata: \($0.path) — \($0.reason)") }
            print("Geri almak için: trimly undo \(summary.runID)")
        }
    }
}
