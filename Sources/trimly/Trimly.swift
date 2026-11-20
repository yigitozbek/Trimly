import ArgumentParser

@main
struct Trimly: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trimly",
        abstract: "Yerel yapay zeka destekli, güvenli klasör düzenleyici.",
        version: "0.1.0"
    )
}
