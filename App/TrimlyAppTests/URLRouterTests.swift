import Foundation
import Testing
@testable import TrimlyApp

@Suite(.tags(.fileSystem))
struct URLRouterTests {
    @Test func routesEncodedFolderPath() throws {
        let folder = try TestFS.folder("Kişisel Belgeler + Arşiv", in: try TestFS.tempDir())
        let url = URLRouter.organizeURL(for: folder)
        #expect(url.scheme == "trimly" && url.host() == "organize")
        #expect(url.absoluteString.contains(" ") == false)
        #expect(try URLRouter.route(url) == .organize(folder.standardizedFileURL))
    }

    @Test func rejectsFile() throws {
        let file = try TestFS.file("a.txt", in: try TestFS.tempDir())
        #expect(throws: URLRouter.RouteError.notAFolder(file.path)) {
            try URLRouter.route(URLRouter.organizeURL(for: file))
        }
    }

    @Test(arguments: ["trimly://organize", "trimly://organize?path="])
    func rejectsMissingPath(_ string: String) {
        #expect(throws: URLRouter.RouteError.missingPath) {
            try URLRouter.route(URL(string: string)!)
        }
    }

    @Test(arguments: ["trimly://delete?path=/tmp", "https://organize?path=/tmp"])
    func rejectsUnsupported(_ string: String) {
        #expect(throws: URLRouter.RouteError.unsupported) {
            try URLRouter.route(URL(string: string)!)
        }
    }
}
