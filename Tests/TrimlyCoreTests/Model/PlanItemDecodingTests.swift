import Foundation
import Testing
@testable import TrimlyCore

struct PlanItemDecodingTests {
    func dropping(_ keys: [String], from data: Data) throws -> Data {
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        keys.forEach { json.removeValue(forKey: $0) }
        return try JSONSerialization.data(withJSONObject: json)
    }

    @Test func decodesPhase2ItemWithoutTreeFields() throws {
        let item = PlanItem.stub("a.pdf", in: try TestFS.tempDir(), category: "documents")
        let data = try dropping(["relativePath", "depth", "parentID", "folderMode", "covered"], from: JSONCoding.encoder.encode(item))
        let decoded = try JSONCoding.decoder.decode(PlanItem.self, from: data)
        #expect(decoded.relativePath == "a.pdf" && decoded.depth == 0 && decoded.parentID == nil)
        #expect(decoded.folderMode == nil && decoded.covered == false)
    }

    @Test func planWithoutTruncatedDecodes() throws {
        let plan = Plan.stub(root: try TestFS.tempDir(), items: [])
        let data = try dropping(["truncated"], from: JSONCoding.encoder.encode(plan))
        #expect(try JSONCoding.decoder.decode(Plan.self, from: data).truncated == false)
    }

    @Test func engineVersionIsFive() {
        #expect(Plan.currentEngineVersion == 5)
    }

    @Test func decodesPhase3aItemWithoutTagFields() throws {
        let item = PlanItem.stub("a.pdf", in: try TestFS.tempDir(), category: "documents")
        let data = try dropping(["existingTags", "tagsToAdd"], from: JSONCoding.encoder.encode(item))
        let decoded = try JSONCoding.decoder.decode(PlanItem.self, from: data)
        #expect(decoded.existingTags.isEmpty && decoded.tagsToAdd.isEmpty)
    }

    @Test func decodesPhase3bItemWithoutTrashFields() throws {
        let item = PlanItem.stub("a.pdf", in: try TestFS.tempDir(), category: "documents")
        let data = try dropping(["trashReason", "trashedRunID"], from: JSONCoding.encoder.encode(item))
        let decoded = try JSONCoding.decoder.decode(PlanItem.self, from: data)
        #expect(decoded.trashReason == nil && decoded.trashedRunID == nil)
    }
}
