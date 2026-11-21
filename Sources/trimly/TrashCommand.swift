import ArgumentParser
import Foundation
import TrimlyCore

struct TrashCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trash",
        abstract: "Tek bir çöp adayını Çöp Kutusu'na atar (journal'lı; geri alınabilir)."
    )

    @Argument(help: "Plan kimliği.")
    var planID: String

    @Argument(help: "Öğe kimliği (plan tablosundaki 8 karakterlik kod).")
    var itemID: String

    @Flag(help: "Son onayı sormadan çöpe at.")
    var yes = false

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            let plan = try env.store.load(id: planID)
            guard let item = plan.items.first(where: { $0.id == itemID }) else {
                throw PlanError.itemNotFound(itemID)
            }
            guard let reason = item.trashReason, item.trashedRunID == nil else {
                throw ExecutionError.notTrashCandidate
            }
            print("\(item.name) → Çöp Kutusu (\(reason.label))")
            if yes == false {
                print("Çöp Kutusu'na atılsın mı? [e/H] ", terminator: "")
                let answer = (readLine() ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                guard ["e", "evet", "y", "yes"].contains(answer) else {
                    print("İptal edildi.")
                    return
                }
            }
            let summary = try await Executor(directory: env.directory).trash(planID: planID, itemID: itemID)
            if summary.trashed == 1 {
                print("Çöp'e atılan: 1")
                print("Geri almak için: trimly undo \(summary.runID)")
            } else {
                print("Çöp'e atılan: 0 · Atlanan: \(summary.skipped.count) · Hatalı: \(summary.failed.count)")
                summary.skipped.forEach { print("  atlandı: \($0.path) — \($0.reason)") }
                summary.failed.forEach { print("  hata: \($0.path) — \($0.reason)") }
            }
        }
    }
}
