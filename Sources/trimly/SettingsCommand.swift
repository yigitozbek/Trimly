import ArgumentParser
import Foundation
import TrimlyCore

struct SettingsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "settings", abstract: "Ayarları gösterir, dosya yolunu basar veya varsayılanlara döndürür.")

    @Flag(help: "Ayar dosyasının yolunu bas.")
    var path = false

    @Flag(help: "Varsayılan ayarları yaz.")
    var reset = false

    @OptionGroup var global: GlobalOptions

    func run() async throws {
        try await Output.guarding {
            let env = try global.environment()
            if path {
                print(env.directory.settingsURL.path)
            } else if reset {
                try SettingsStore.save(Settings(), to: env.directory)
                print("Varsayılan ayarlar yazıldı: \(env.directory.settingsURL.path)")
            } else {
                print(String(decoding: try JSONCoding.encoder.encode(env.settings), as: UTF8.self))
            }
        }
    }
}
