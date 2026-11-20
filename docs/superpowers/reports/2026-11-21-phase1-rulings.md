# Faz 1 — Uygulama kararları ve ertelenen bulgular

Kaynak: SDD ledger (inline yürütme). Her satır: karar — gerekçe — yanlışsa maliyeti.

## Kararlar (Ruling)

- Setup: Ruling: no git worktree — repo was created this session (empty, nothing to isolate); work on branch phase1-core-cli instead of main — cost if wrong: none (branch isolates main).
- Setup: Ruling: Task 1 Step 1 (git init + .gitignore) done during setup; .gitignore also ignores .superpowers/ and .DS_Store — needed so the SDD workspace is not committed — cost if wrong: none.
- | T1 → all | "each type in own file" (Global) vs T1 Files `Model/Plan.swift` etc. | Ruling: Global Constraint wins — every type in `<Type>.swift` within listed folder — cost: none |
- | T10 → T11–T13 | `PlannerFixture` | Ruling: fixture sets `recentMinutes = 0` so fresh temp files are not skipped if Spotlight reports `kMDItemDateAdded = now` — cost: recent-skip covered only by T5 unit tests |
- Task 1: Ruling: added test readReportsSizeForFilesAndNilForDirectories beyond brief — covers read() directory branch used by Executor/Undoer — cost: none
- Task 3: Ruling: added tests upperCaseExtensionIsLowered + modifiedOnly branch in resolvePriority beyond brief — cover spec's lowercase-ext rule and last fallback — cost: none
- Task 4: Ruling: plan's `Scanner` renamed `FolderScanner` (file Scan/FolderScanner.swift, tests FolderScannerTests) — collides with Foundation.Scanner, tests resolved to NSScanner — cost: none; later tasks use FolderScanner
- Task 4: Ruling: FolderScanner rebuilds item URLs from root (root.appending(name)) instead of using listing URLs — macOS listing returns /private/var while resolvingSymlinksInPath gives /var; mixed forms would break source/target comparisons — cost: none
- Task 4: Ruling: TestFS.tempDir uses realpath (canonical /private/var) instead of resolvingSymlinksInPath — plan's comment was wrong about its effect — cost: none
- Task 4: Ruling: added tests keepsCompoundExtension + url-from-root assertion beyond brief — cost: none
- Task 5: Ruling: added test plainFolderIsNotSkipped beyond brief — guards against marker check false positives — cost: none
- Task 6: Ruling: screenshot time hint takes the LAST h.mm.ss match; .key is Keynote when kind == .package or utType contains "keynote" — robust to both UTType spellings — cost: none
- Task 7: Ruling: PDF/DOCX test generators live in Fixtures/DocumentFactory.swift (not inline in the test) — swift-testing-pro: fixtures in dedicated files — cost: none
- Task 8: Ruling: RecordingTransport.bodyJSON is a static helper taking URLRequest (plan: actor method bodyJSON(at:)) — [String: Any] is non-Sendable and cannot leave the actor — cost: none
- Task 8: Ruling: added test cancellationIsNotRetried beyond brief — pins swift-concurrency-pro rule (never swallow/retry CancellationError) — cost: none
- Task 9: Ruling: TargetAssigner in its own file Naming/TargetAssigner.swift (plan listed both in TargetResolver.swift) — one type per file — cost: none
- Task 9: Ruling: conflict suffix keeps the original extension's case (X.PDF → X_3.PDF) as the brief's test requires — cost: none
- Task 9: Ruling: added test assignerFallsBackToDefaultDescription; shared Fixtures/PlanItem+Stub.swift (PlanItem.stub, Plan.stub, Plan.item) for T9–T13 — cost: none
- Task 10: Ruling: plan is also checkpointed right after the rule pass (before LLM batches) — interruption during batch 1 still leaves resumable rule results — cost: one extra small write
- Task 10: Ruling: resumed plans keep their settingsSnapshot (not current settings) — targets stay consistent with the classified half — cost: settings changed mid-run apply only to new plans
- Task 10: Ruling: unclassified placeholder items in checkpoints use status .review + classified=false; reclassified on resume — cost: none
- Task 10: Ruling: PlanStats computed in PlanStats(plan:) init, Planner.stats delegates — one type per file — cost: none
- Task 10: Ruling: persistence assertion compares targets, not whole Plan — ISO8601 drops sub-second precision (spec's 1 s tolerance) — cost: none
- Task 11: Ruling: review() is a no-op (returns plan) when provider is nil, LLM disabled or no candidates — CLI reports nothing changed instead of failing — cost: none
- Task 11: Ruling: review() on cancellation does not checkpoint partial stage-2 results — stage 2 is short and re-runnable — cost: redo of a few items
- Task 11: Ruling: PlanEditor.set with a category/description clears skipReason and un-skips the item — explicit manual decision overrides an ignore rule — cost: user can move an ignored item only deliberately, per item
- Task 11: Ruling: bulkApprove returns 0 on applied plans; review() lives in Planning/Planner+Review.swift — cost: none
- Task 12: Ruling: movesApprovedFolderWithContents asserts the plan's own target (Gorseller/Album — jpg maps to images) instead of the brief's 'Fotograflar/Album' — brief guessed the category — cost: none
- Task 12: Ruling: apply-time conflicts reuse TargetResolver.reserve (fresh disk read) instead of a second suffix implementation — cost: none
- Task 12: Ruling: Recovery also resolves pending mkdir lines (exists → done) — complete coverage of op kinds — cost: none
- Task 12: Ruling: added test omitsNilFields — cost: none
- Task 13: Ruling: runs with zero done moves count as 'undone' (vacuous) so undo(nil) skips empty runs — cost: undo(nil) never targets a no-op run
- Task 13: Ruling: skipped undo steps are journaled as state=skipped and retried on the next undo — user can fix the conflict and undo again — cost: skipped items re-reported each time
- Task 13: Ruling: Undoer runs Recovery on its journal first; RunInfo/RunLog/UndoSummary/UndoError each in own file — cost: none
- Task 13: Ruling: merged brief's undoDefaultsToLatestRun + runLogListsNewestFirst into one test (shared two-run setup); undoErrors also covers runNotFound — cost: none
- Task 14: Ruling: CLI split one command per file (Trimly, GlobalOptions, CLIEnvironment, Output, 8 command files) instead of PlanCommands/RunCommands — one type per file — cost: none
- Task 14: Ruling: plan table includes the 8-char item id (needed by `trimly set`); skipped items shown as grouped counts — keeps 385-item output readable — cost: none
- Task 14: Ruling: PlanStats.decisiveRule = decidedBy rule && confidence 1.0 (plan: status != review) — plan's definition counted weak-rule fallbacks of critical items as decisive; test statsCountsByReason now asserts 3 (RED→GREEN) — cost: none
- Task 14: Ruling: apply with zero approved items prints a notice and does not mark the plan applied; review fails with exit 1 when Ollama/stage2 model unavailable — cost: none
- Task 14: Ruling: smoke script also runs `trimly runs` — cost: none
- Task 15: Ruling: MetadataReader uses one MDItemCopyAttributes call instead of five MDItemCopyAttribute calls — sample showed Spotlight IPC dominating; 388-item rules-only plan 1.0 s → 0.43 s, identical stats (behavior-preserving refactor under green suite) — cost: none
- Task 15: Ruling: real-data finding — .keystore/.jks (Android signing keys) present in ~/Downloads were not critical; added to criticalExtensions + certificates (decisive). Also aab/jnlp → installers, htm → code. TDD RED (7 issues) → GREEN 120/120 — cost: none
- Task 15: Ruling: .p8/.ppk/.log/.ips not added (not observed or debatable) — listed as suggestions in report — cost: they still go to LLM/review
- Task 15: Ruling: real-data finding — LLM appended underscore-glued YYYYMMDD to 8/107 descriptions; sanitizer pattern now uses digit lookarounds + month/day validation + optional HHMM[SS]; added keepsNumbersThatAreNotDates (old pattern wrongly stripped order numbers). RED 3 → GREEN 121/121 — cost: an 8-digit ID that is also a valid date gets stripped
- Final: Ruling: I5 changes product behavior (LLM verdict certificates/health/officialDocs ⇒ critical; secret markers ⇒ critical, no content) beyond spec's ext/keyword list — spec anti-goal "LLM must not decide critical files alone" — cost: a few more items need per-item approval
- Final: Ruling: declined "folders containing critical files move as a unit under approve --folders" — spec makes folders explicit opt-in units — cost: a critical file inside an approved folder moves with it (undoable)
- Final: Ruling: declined "prompt injection via preview" — local model, enum-constrained folder, critical items get no preview — cost: an undoable misfiling
- Final: Ruling: declined "folder undo checks existence only" — explicit plan decision (Finder rewrites .DS_Store/mtime) — cost: a different folder at the same path could be moved back
- Final: Ruling: declined "cross-volume moves in central mode" — opt-in mode, source stays intact on failure — cost: slow copy on another volume
- Final: Ruling: declined "Executor/Undoer not @concurrent" — only makePlan/review required; Phase 2 must call them off the main actor — cost: UI work in Phase 2
- Final: Ruling: declined "case-sensitive volumes / NFC-NFD under keepOriginal" — safe failure (moveItem refuses, reported) — cost: an item reported failed
- Final: Ruling: declined "plan on a category folder nests a category folder" — harmless — cost: odd nesting
- Final: Ruling: declined "stage-2 swap pressure / throughput" — measured, left to user per plan — cost: slow machine during review

## Final review düzeltmeleri

- C1 undo could delete a user file replacing a created folder — undoNeverDeletesAFileThatReplacedACreatedFolder RED→GREEN, suite 130/130
- C2 mobileprovision (15 chars) lost extension / never critical — everyCriticalAndMappedExtensionSurvives RED→GREEN, suite 130/130
- I1 skipped critical item could be un-skipped then bulk-approved — unskippedCriticalItemStaysCritical RED→GREEN, suite 130/130
- I2 stage-2 review rewrote targets of approved items — reviewLeavesApprovedItemsAlone RED→GREEN, suite 130/130
- I3 torn journal line broke CLI and hid run from undo — tornLastLineIsIgnoredAndNextAppendStartsOnNewLine + recoverAllSkipsUnreadableJournals RED→GREEN, suite 130/130
- I4 critical detector missed glued/compound/secret-file names — critical(_:) new cases RED→GREEN, suite 130/130
- I5 LLM-sensitive categories and key-material previews auto-approved — llmSensitiveCategoryMakesItemCritical + secretMarkersBlockPreviewAndMarkCritical RED→GREEN, suite 130/130
- I6 sql.gz/csv.gz/tar.zst lost inner extension — compressedKnownExtensionsStayCompound RED→GREEN, suite 130/130

## Ertelenen minor bulgular

- Executor marks a move 'failed' if the 'done' journal write fails after a successful move (undo then won't restore it)
- Journal.create truncates an existing file; appends lack O_APPEND; no data-dir lock; Recovery runs on journals a live apply is writing (matters when app + CLI share the data dir in Phase 2)
- PlanEditor.set/bulkApprove accept inProgress plans; finalize can silently undo an explicit --reject on resume
- `trimly apply` on an applied plan prompts [e/H] before reporting it is already applied
- sanitizer strips only exact category tokens; inflected forms survive ("Faturasi")
- runs with zero completed moves count as undone, so undo(nil) never removes folders they created
- spec's "retry with new suffix on move race" not implemented (move reported failed)
- mkdir journaled after creation; a crash in between leaves an unjournaled folder (Recovery's pending-mkdir branch is dead)
- PlanStore.latestResumable decodes every saved plan on each run
- no tests for resuming an interrupted undo / recovering a pending undo line; recent-file rule only unit-tested
- try! in OllamaProviderTests.reply helper
