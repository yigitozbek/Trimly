import ArgumentParser
import Foundation
import TrimlyCore

struct ApproveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "approve", abstract: "Filtreye uyan öğeleri toplu onaylar; kritik öğeler asla dahil edilmez.")

    @Argument(help: "Plan kimliği.")
    var planID: String

    @Option(help: "Yalnızca bu kategori kimliği.")
    var category: String?

    @Option(help: "Yalnızca bu inceleme sebebi: lowConfidence, llmError, weakRuleNoLLM, folder.")
    var reason: String?

    @Option(name: .customLong("min-confidence"), help: "En düşük güven (0–1).")
    var minConfidence: Double?

    @Flag(help: "Klasör öğelerini de dahil et.")
    var folders = false

    @OptionGroup var global: GlobalOptions

    func validate() throws {
        if let reason, ReviewReason(rawValue: reason) == nil {
            throw ValidationError("Geçersiz sebep: \(reason). Geçerli: \(ReviewReason.allCases.map(\.rawValue).joined(separator: ", "))")
        }
    }

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            var plan = try env.store.load(id: planID)
            let count = PlanEditor.bulkApprove(
                &plan,
                categoryID: category,
                reviewReason: reason.flatMap(ReviewReason.init(rawValue:)),
                minConfidence: minConfidence,
                includeFolders: folders
            )
            try env.store.save(plan)
            print("\(count) öğe onaylandı (kritik öğeler toplu onaya dahil edilmez).")
        }
    }
}
