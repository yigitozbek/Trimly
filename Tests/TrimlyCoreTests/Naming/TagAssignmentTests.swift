import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct TagAssignmentTests {
    func assigned(_ items: [PlanItem], root: URL, _ change: (inout Settings) -> Void = { _ in }) -> Plan {
        var plan = Plan.stub(root: root, items: items)
        change(&plan.settingsSnapshot)
        CoverageResolver.apply(&plan)
        TargetAssigner.assign(&plan)
        return plan
    }

    @Test func moveModeAddsCategoryTag() throws {
        let root = try TestFS.tempDir()
        let invoice = PlanItem.stub("a.pdf", in: root, category: "invoices", description: "Enerjisa")
        #expect(assigned([invoice], root: root).item("a.pdf").tagsToAdd == ["Fatura"])
        #expect(assigned([invoice], root: root) { $0.addCategoryTags = false }.item("a.pdf").tagsToAdd.isEmpty)
    }

    @Test(.tags(.edgeCase)) func existingTagIsNotAddedTwice() throws {
        let root = try TestFS.tempDir()
        let invoice = PlanItem.stub("a.pdf", in: root, category: "invoices", description: "Enerjisa", existingTags: ["fatura"])
        let moved = assigned([invoice], root: root).item("a.pdf")
        #expect(moved.tagsToAdd.isEmpty && moved.target != nil)
        let tagOnly = assigned([invoice], root: root) { $0.targetMode = .tagOnly }.item("a.pdf")
        #expect(tagOnly.status == .skipped && tagOnly.skipReason == "Zaten etiketli")
    }

    @Test func tagOnlyHasNoTargetsButIsApprovable() throws {
        let root = try TestFS.tempDir()
        let invoice = PlanItem.stub("a.pdf", in: root, category: "invoices", description: "Enerjisa")
        var plan = assigned([invoice], root: root) { $0.targetMode = .tagOnly; $0.addCategoryTags = false }
        #expect(plan.item("a.pdf").target == nil && plan.item("a.pdf").tagsToAdd == ["Fatura"])
        var bulk = plan
        #expect(PlanEditor.bulkApprove(&bulk, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: false) == 1)
        #expect(PlanEditor.setApproval(&plan, itemIDs: [invoice.id], approved: true) == 1)
    }

    @Test func coveredItemsGetNoTags() throws {
        let root = try TestFS.tempDir()
        let folder = PlanItem.stub("Tatil", in: root, category: "photos", kind: .folder, status: .review, reviewReason: .folder, folderMode: .keep)
        let child = PlanItem.stub("1.jpg", in: root, category: "photos", parent: folder)
        let plan = assigned([folder, child], root: root) { $0.targetMode = .tagOnly }
        #expect(plan.item(path: "Tatil/1.jpg").tagsToAdd.isEmpty)
        #expect(plan.item("Tatil").tagsToAdd == ["Fotograf"])
    }
}
