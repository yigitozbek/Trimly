import ArgumentParser
import Foundation
import TrimlyCore

struct SetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Tek bir öğe için elle karar verir (kategori, açıklama, onay).")

    enum Decision: String, EnumerableFlag {
        case approve
        case reject
    }

    @Argument(help: "Plan kimliği.")
    var planID: String

    @Argument(help: "Öğe kimliği (plan tablosundaki 8 karakterlik kod).")
    var itemID: String

    @Option(help: "Kategori kimliği (ör. invoices, documents).")
    var category: String?

    @Option(help: "Kısa açıklama (ör. \"Kira Ocak\").")
    var name: String?

    @Flag(help: "Onayla veya reddet. Kritik öğeler yalnızca bu yolla onaylanabilir.")
    var decision: Decision?

    @Option(help: "Klasör modu: keep (bütün tut, tek parça taşınır) veya distribute (dağıt, içi tek tek düzenlenir).")
    var mode: FolderMode?

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            var plan = try env.store.load(id: planID)
            if let mode {
                try PlanEditor.setFolderMode(&plan, itemID: itemID, mode: mode)
            }
            if category != nil || name != nil || decision != nil || mode == nil {
                try PlanEditor.set(&plan, itemID: itemID, categoryID: category, description: name, approve: decision.map { $0 == .approve })
            }
            try env.store.save(plan)
            if let item = plan.items.first(where: { $0.id == itemID }) {
                print(Output.row(item, root: plan.root, coveredCount: Output.coveredCount(of: item, in: plan)))
            }
        }
    }
}
