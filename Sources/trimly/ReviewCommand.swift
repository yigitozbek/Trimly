import ArgumentParser
import Foundation
import TrimlyCore

struct ReviewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "review", abstract: "İnceleme ve kritik öğeleri büyük modelle (2. aşama) yeniden değerlendirir.")

    @Argument(help: "Plan kimliği.")
    var planID: String

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            if let problem = await env.llmProblem(for: env.settings.stage2Model) {
                Output.printError("\(problem); 2. aşama çalıştırılamıyor.")
                throw ExitCode.failure
            }
            let planner = Planner(settings: env.settings, store: env.store, provider: env.provider(), progress: Output.progress)
            let plan = try await planner.review(planID: planID)
            Output.printPlan(plan)
            Output.printStats(Planner.stats(plan))
            print("Plan güncellendi: \(plan.id)")
        }
    }
}
