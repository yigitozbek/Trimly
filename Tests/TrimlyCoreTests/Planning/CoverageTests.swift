import Foundation
import Testing
@testable import TrimlyCore

@Suite(.tags(.fileSystem))
struct CoverageTests {
    @Test func keepFolderCoversDescendants() throws {
        let root = try TestFS.tempDir()
        let folder = PlanItem.stub("Tatil", in: root, category: "photos", kind: .folder, status: .review, reviewReason: .folder, folderMode: .keep)
        let child = PlanItem.stub("1.jpg", in: root, category: "images", approved: true, parent: folder)
        var plan = Plan.stub(root: root, items: [folder, child])
        CoverageResolver.apply(&plan)
        TargetAssigner.assign(&plan)
        #expect(plan.item(path: "Tatil/1.jpg").covered && plan.item(path: "Tatil/1.jpg").approved == false)
        #expect(plan.item(path: "Tatil/1.jpg").target == nil)
        #expect(plan.item("Tatil").target?.path == root.appending(path: "Fotograflar/Tatil").path)
    }

    @Test func distributeFolderHasNoTargetAndChildrenGetTargets() throws {
        let root = try TestFS.tempDir()
        let folder = PlanItem.stub("Rastgele", in: root, kind: .folder, status: .review, reviewReason: .mixedFolder, folderMode: .distribute)
        let child = PlanItem.stub("a.pdf", in: root, category: "documents", description: "Rapor", approved: true, parent: folder)
        var plan = Plan.stub(root: root, items: [folder, child])
        CoverageResolver.apply(&plan)
        TargetAssigner.assign(&plan)
        #expect(plan.item("Rastgele").target == nil && plan.item("Rastgele").approved == false)
        #expect(plan.item(path: "Rastgele/a.pdf").covered == false)
        #expect(plan.item(path: "Rastgele/a.pdf").target?.path == root.appending(path: "Belgeler/2025-02-10_Belge_Rapor.pdf").path)
    }

    @Test func switchingModesRecomputesCoverageAndApprovals() throws {
        let root = try TestFS.tempDir()
        // The planner gives mixed folders their rule category ("other") so switching to keep yields a target.
        let folder = PlanItem.stub("Rastgele", in: root, category: "other", kind: .folder, status: .review, reviewReason: .mixedFolder, folderMode: .distribute)
        let ready = PlanItem.stub("a.pdf", in: root, category: "documents", description: "Rapor", approved: true, parent: folder)
        let critical = PlanItem.stub("kimlik.pdf", in: root, category: "officialDocs", status: .critical, critical: true, parent: folder)
        var plan = Plan.stub(root: root, items: [folder, ready, critical])
        CoverageResolver.apply(&plan)
        TargetAssigner.assign(&plan)

        try PlanEditor.setFolderMode(&plan, itemID: folder.id, mode: .keep)
        #expect(plan.item(path: "Rastgele/a.pdf").covered && plan.item(path: "Rastgele/a.pdf").approved == false)
        #expect(plan.item("Rastgele").reviewReason == .folder && plan.item("Rastgele").target != nil)

        try PlanEditor.setFolderMode(&plan, itemID: folder.id, mode: .distribute)
        #expect(plan.item(path: "Rastgele/a.pdf").approved)
        #expect(plan.item(path: "Rastgele/kimlik.pdf").approved == false)
        #expect(plan.item("Rastgele").target == nil && plan.item("Rastgele").reviewReason == .mixedFolder)
    }

    @Test func fixedModeFolderRejectsChange() throws {
        let root = try TestFS.tempDir()
        let category = PlanItem.stub(
            "Faturalar", in: root, kind: .folder, status: .skipped, folderMode: .distribute,
            skipReason: Planner.categoryFolderReason, modeLock: "Trimly kategori klasörü"
        )
        let file = PlanItem.stub("a.pdf", in: root, category: "documents")
        var plan = Plan.stub(root: root, items: [category, file])
        #expect(throws: PlanError.folderModeLocked("Trimly kategori klasörü")) {
            try PlanEditor.setFolderMode(&plan, itemID: category.id, mode: .keep)
        }
        #expect(throws: PlanError.notAFolder) {
            try PlanEditor.setFolderMode(&plan, itemID: file.id, mode: .keep)
        }
    }

    @Test(.tags(.edgeCase)) func sameNamesFromDifferentFoldersGetSuffixes() throws {
        let root = try TestFS.tempDir()
        let a = PlanItem.stub("A", in: root, kind: .folder, status: .review, reviewReason: .mixedFolder, folderMode: .distribute)
        let b = PlanItem.stub("B", in: root, kind: .folder, status: .review, reviewReason: .mixedFolder, folderMode: .distribute)
        let fromB = PlanItem.stub("fatura.pdf", in: root, category: "invoices", description: "Enerjisa", parent: b)
        let fromA = PlanItem.stub("fatura.pdf", in: root, category: "invoices", description: "Enerjisa", parent: a)
        var plan = Plan.stub(root: root, items: [b, fromB, a, fromA])
        CoverageResolver.apply(&plan)
        TargetAssigner.assign(&plan)
        #expect(plan.item(path: "A/fatura.pdf").target?.lastPathComponent == "2025-02-10_Fatura_Enerjisa.pdf")
        #expect(plan.item(path: "B/fatura.pdf").target?.lastPathComponent == "2025-02-10_Fatura_Enerjisa_2.pdf")
    }

    @Test(.tags(.edgeCase)) func bulkPathsNeverApproveFolderCarryingCritical() throws {
        let root = try TestFS.tempDir()
        let folder = PlanItem.stub("Tatil", in: root, category: "photos", kind: .folder, status: .review, reviewReason: .folder, folderMode: .keep)
        let critical = PlanItem.stub("kimlik.pdf", in: root, category: "officialDocs", status: .critical, critical: true, parent: folder)
        var plan = Plan.stub(root: root, items: [folder, critical])
        CoverageResolver.apply(&plan)
        TargetAssigner.assign(&plan)
        #expect(plan.foldersCarryingCritical() == [folder.id])
        #expect(PlanEditor.bulkApprove(&plan, categoryID: nil, reviewReason: nil, minConfidence: nil, includeFolders: true) == 0)
        #expect(PlanEditor.setApproval(&plan, itemIDs: [folder.id], approved: true) == 0)
        try PlanEditor.set(&plan, itemID: folder.id, categoryID: nil, description: nil, approve: true)
        #expect(plan.item("Tatil").approved)
    }

    /// Review I4: a manual category edit clears the skip reason but must not unlock the folder.
    @Test(.tags(.edgeCase)) func fixedFolderStaysFixedAfterManualEdit() throws {
        let root = try TestFS.tempDir()
        let category = PlanItem.stub(
            "Faturalar", in: root, kind: .folder, status: .skipped, folderMode: .distribute,
            skipReason: Planner.categoryFolderReason, modeLock: "Trimly kategori klasörü"
        )
        var plan = Plan.stub(root: root, items: [category])
        try PlanEditor.set(&plan, itemID: category.id, categoryID: "documents", description: nil, approve: nil)
        #expect(throws: PlanError.folderModeLocked("Trimly kategori klasörü")) {
            try PlanEditor.setFolderMode(&plan, itemID: category.id, mode: .keep)
        }
        #expect(plan.item("Faturalar").target == nil)
    }

    /// Review I3: a folder whose contents were never listed cannot be distributed.
    @Test func unlistedFolderCannotBeDistributed() throws {
        let root = try TestFS.tempDir()
        let folder = PlanItem.stub("Album", in: root, category: "photos", kind: .folder, status: .review, reviewReason: .folder, folderMode: .keep, listed: false)
        var plan = Plan.stub(root: root, items: [folder])
        #expect(throws: PlanError.folderNotListed) {
            try PlanEditor.setFolderMode(&plan, itemID: folder.id, mode: .distribute)
        }
    }
}
