import Foundation

public enum SettingsStore {
    /// Returns defaults when no settings file exists; never writes.
    public static func load(from directory: DataDirectory) throws -> Settings {
        guard FileManager.default.fileExists(atPath: directory.settingsURL.path) else {
            return Settings()
        }
        let data = try Data(contentsOf: directory.settingsURL)
        return try JSONCoding.decoder.decode(Settings.self, from: data)
    }

    public static func save(_ settings: Settings, to directory: DataDirectory) throws {
        try FileManager.default.createDirectory(at: directory.root, withIntermediateDirectories: true)
        try JSONCoding.encoder.encode(settings).write(to: directory.settingsURL, options: .atomic)
    }
}
