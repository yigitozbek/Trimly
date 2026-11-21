import ArgumentParser

@main
struct Trimly: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trimly",
        abstract: "Yerel yapay zeka destekli, güvenli klasör düzenleyici.",
        discussion: "Akış: plan (önizleme) → set/approve (karar) → apply (journal'lı taşıma) → undo (geri alma).",
        version: "0.1.0",
        subcommands: [
            PlanCommand.self, ReviewCommand.self, SetCommand.self, ApproveCommand.self,
            ApplyCommand.self, TrashCommand.self, UndoCommand.self, RunsCommand.self, SettingsCommand.self
        ]
    )
}
