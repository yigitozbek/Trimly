import Foundation

/// Parses and builds `trimly://organize?path=<percent-encoded folder>` links (Finder extension, Dock menu, scripts).
enum URLRouter {
    enum Route: Equatable {
        case organize(URL)
    }

    enum RouteError: Error, Equatable {
        case unsupported
        case missingPath
        case notAFolder(String)
    }

    static func route(_ url: URL) throws -> Route {
        guard url.scheme == "trimly", url.host() == "organize" else {
            throw RouteError.unsupported
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let path = components?.queryItems?.first(where: { $0.name == "path" })?.value, path.isEmpty == false else {
            throw RouteError.missingPath
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RouteError.notAFolder(path)
        }
        return .organize(URL(filePath: path, directoryHint: .isDirectory).standardizedFileURL)
    }

    static func message(for error: RouteError) -> String {
        switch error {
        case .unsupported: "Bu bağlantı Trimly tarafından desteklenmiyor."
        case .missingPath: "Bağlantıda klasör yolu yok."
        case .notAFolder(let path): "Klasör bulunamadı: \(path)"
        }
    }

    static func organizeURL(for folder: URL) -> URL {
        var components = URLComponents()
        components.scheme = "trimly"
        components.host = "organize"
        components.queryItems = [URLQueryItem(name: "path", value: folder.path)]
        return components.url!
    }
}
