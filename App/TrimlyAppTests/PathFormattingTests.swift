import Foundation
import Testing
@testable import TrimlyApp

struct PathFormattingTests {
    @Test func relativeInsideRootAndAbsoluteOutside() {
        let root = URL(filePath: "/Users/x/Downloads", directoryHint: .isDirectory)
        #expect(PathFormatting.relative(URL(filePath: "/Users/x/Downloads/Faturalar/a.pdf"), to: root) == "Faturalar/a.pdf")
        #expect(PathFormatting.relative(URL(filePath: "/Users/x/Documents/Arsiv/a.pdf"), to: root) == "/Users/x/Documents/Arsiv/a.pdf")
    }

    @Test func displayNameAbbreviatesHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(PathFormatting.displayName(home.appending(path: "Downloads")) == "~/Downloads")
        #expect(PathFormatting.displayName(URL(filePath: "/tmp/x")) == "/tmp/x")
    }
}
