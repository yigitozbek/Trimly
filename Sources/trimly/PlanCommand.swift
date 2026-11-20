import ArgumentParser
import Foundation
import TrimlyCore

struct PlanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "plan", abstract: "Klasörü tarar ve önizleme planı üretir; hiçbir dosyaya dokunmaz.")

    @Argument(help: "Düzenlenecek klasör.")
    var folder: String

    @Flag(name: .customLong("no-llm"), help: "Yalnızca deterministik kuralları kullan.")
    var noLLM = false

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            let root = CLIEnvironment.absoluteURL(folder)
            var useLLM = noLLM == false && env.settings.llmEnabled
            if useLLM, let problem = await env.llmProblem(for: env.settings.stage1Model) {
                Output.warn("\(problem); yalnızca kurallar kullanılacak.")
                useLLM = false
            }
            let planner = Planner(settings: env.settings, store: env.store, provider: env.provider(), progress: Output.progress)
            let plan = try await planner.makePlan(root: root, useLLM: useLLM)
            Output.printPlan(plan)
            Output.printStats(Planner.stats(plan))
            print("Plan kaydedildi: \(plan.id)")
        }
    }
}
