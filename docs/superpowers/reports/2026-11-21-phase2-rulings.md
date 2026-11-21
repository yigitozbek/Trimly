# Faz 2 — Uygulama kararları ve ertelenen bulgular

Kaynak: SDD ledger (inline yürütme). Her satır: karar — gerekçe — yanlışsa maliyeti.

## Kararlar (Ruling)

- | T3 TrimlyCoreTests Fixtures/Tags.swift | TestFS uses no tags; MockLLMProvider no tags — app target gets its own Tag extension if needed | Ruling: app tests define their own Tags.swift (fileSystem, edgeCase) — sharing Tags.swift would duplicate nothing but keeps targets independent — cost: none |
- Task 1: Ruling: Executor and Undoer marked Sendable (required to call their @concurrent methods from the main actor); lock held via withExtendedLifetime around a private *Locked body — ARC may otherwise release it early — cost: none
- Task 2: Ruling: notReady message is now generic for CLI and app ("önce taramayı bitirin" instead of the CLI-only "önce `trimly plan` ile bitirin") — one shared UserMessage — cost: CLI text slightly less specific
- Task 2: Ruling: added bulkRejectIgnoresAppliedPlans and extra UserMessage cases (http, malformed, runNotFound) — cost: none
- Task 3: Ruling: DEVELOPMENT_TEAM is 8FCFVBQ4LK (cert OU / Xcode account); UBF7FMWA6S in the cert name is the member ID — fixed in project.yml and both design docs — cost: none
- Task 3: Ruling: TEST_HOST/BUNDLE_LOADER set explicitly (XcodeGen derived it from target name TrimlyApp, product is Trimly) — cost: none
- Task 3: Ruling: LaunchState.launchedByURL is set in PlanWindow.onOpenURL, not AppDelegate.application(_:open:) — implementing that delegate method can swallow URLs before SwiftUI's onOpenURL — cost: flag is set slightly later (after the plan window exists)
- Task 3: Ruling: AppFixture created in Task 4 (where its API is defined), Tags.swift added to app tests now — cost: none
- Task 3: Ruling: screencapture fails (no Screen Recording permission); manual verification uses System Events accessibility dumps (Accessibility permission is granted) instead of screenshots — cost: no pixel-level visual check; layout verified structurally
- Task 4: Ruling: RunInfo gains Identifiable (id = runID) in TrimlyCore instead of a retroactive conformance in the app — cost: none
- Task 4: Ruling: AppFixture.environment defaults to UnreachableProvider (Fixtures/UnreachableProvider.swift) so no app test can hit a real Ollama — cost: none
- Task 4: Ruling: added PathFormattingTests (relative/displayName) beyond brief — cost: none
- Task 5: Ruling: progress uses AsyncStream.makeStream + `async let` consumer (structured) instead of a task group — same effect, simpler; the scan itself runs in a stored Task so the İptal button can cancel it, and withTaskCancellationHandler forwards the caller's cancellation (window closing) — cost: none
- Task 5: Ruling: every edit re-reads the plan from disk before applying (so a CLI apply is detected as alreadyApplied) — cost: one small file read per edit
- Task 5: Ruling: search uses localizedStandardContains (case/diacritic-insensitive; "KİM" finds "kimlik.pdf"), lists sorted with localizedStandardCompare — cost: none
- Task 6: Ruling: core Planner.review no longer checks snapshot.llmEnabled — otherwise "scan with LLM off, enable, Detaylı incele" silently did nothing; test reviewRunsEvenIfPlanWasMadeWithLLMDisabled RED→GREEN — cost: `trimly review` on a rules-only plan now really calls the model (it already checks Ollama first)
- Task 6: Ruling: added PlanSession.refreshHealth() (called by start(); a disabled LLM is never contacted) — needed so stage2Available is known for loaded plans too — cost: one health request per window open when LLM is enabled
- Task 6: Ruling: applySummary is a struct ApplySummary + CategoryCount (plan said a tuple) — Equatable/testable, one type per file — cost: none
- Task 6: Ruling: stage-2 failure sets errorMessage and returns to .idle (not .failed) — a failed second opinion must not block applying — cost: none
- Task 7: Ruling: StartView/RunsList helper methods returning some View extracted into ShortcutButton/RunRow structs and button actions into methods (swiftui-pro views rules); ItemRow uses local @State mirrored to the session via onChange instead of Binding(get:set:) (swiftui-pro data rules); added ItemFormatting + tests and TRIMLY_DATA_DIR override (manual testing without touching the real data dir) — cost: none
- Task 8: Ruling: settings tabs use tabItem (swiftui-pro prefers the Tab API, but it needs macOS 15 and the target is 14) — cost: none; revisit if the target moves to 15
- Task 8: Ruling: SettingsModel.refreshHealth asks Ollama even when the LLM is disabled (user-initiated in the settings window, so models can be chosen before enabling) — cost: one request when the settings window opens
- Task 8: Ruling: added NamingPreset.title, SettingsFootnote, ModelPicker (text-field fallback), StringListEditor/RemoveButton as separate views — cost: none
- Task 9: Ruling: LaunchState re-implemented as time-bounded (link within 3 s of launch) after S1 showed the start window opening on cold URL launch; a later link (Dock menu/Finder) never closes the start window; tests LaunchStateTests RED→GREEN — cost: a link arriving >3 s after a slow launch leaves the start window open (harmless)
- Task 9: Ruling: manual verification via System Events AX queries + launchctl setenv TRIMLY_DATA_DIR (no screenshots: no Screen Recording permission) — cost: no pixel-level check
- Post-T9 (user request): Ruling: GENERATE_INFOPLIST_FILE YES + INFOPLIST_KEY_CFBundleDisplayName=Trimly, INFOPLIST_KEY_LSApplicationCategoryType=public.app-category.utilities so Xcode's General tab shows them; Info.plist kept for URL types/usage strings (merged) — cost: none
- Post-T9 (user request): Ruling: pending-section 'Tümünü seç' covers visible non-critical rows incl. folders (explicit click = opt-in); critical rows excluded per spec barrier; new core PlanEditor.setApproval(itemIDs:approved:) with tests — cost: critical items still need per-row approval
- Final: Ruling: declined "commits 7641b9e/6d49e5e outside range" — spot-checked by reviewer; select-all inherits C1 and is covered by the C1 busy guard — cost: none
- Final: Ruling: declined "INCIDENT" — user-confirmed deliberate use; reviewer confirmed only ApplySheet→Uygula moves files forward — cost: none
- Final: Ruling: declined "visual layout/icons/component choice" — spec §9 builder's call — cost: none
- Final: Ruling: declined "Turkish-only UI" — spec non-goal — cost: none
- Final: Ruling: declined "Phase 1 scanner not cancellable before first checkpoint; crash mid-apply leaves plan ready" — pre-existing core, recovery fixes the journal — cost: a long initial scan cannot be interrupted before its first checkpoint
- Final: Ruling: declined "trimly review contacts Ollama when llmEnabled is false" — explicit command (Task 6 ruling) — cost: none
- Final: Ruling: declined "reentrant NSTableView warnings" — no visible glitch — cost: a future SDK may assert
- Final: Ruling: declined "critical items' metadata (name, Spotlight title) sent to the LLM" — spec restricts content only — cost: names of sensitive files reach the local model
- Final: Ruling: declined "Dock menu with several registered dev builds" — dev-only — cost: none
- Final: Ruling: declined "deep performance pass" — not requested — cost: none
- Final: Ruling: no macOS 15 defaultLaunchBehavior branch — time-bounded LaunchState covers macOS 14+ and .suppressed would hide the start window on normal launches too — cost: none
- Final: Ruling: I8 duplicate-window dedupe NOT shipped — the bridge-window approach could not be verified (window restoration + trimly:// routed to the user's Xcode DerivedData build); reverted to verified in-place behaviour; deferred to Phase 3 (Finder extension uses links too) — cost: the same folder can still get two windows; both are safe because apply checks the on-disk approvals and edits re-read under the lock
- Final: Ruling: stage2Available now checks the plan snapshot's stage-2 model (the model review actually uses) — touched while caching settings — cost: none
- Final: Ruling: window state restoration disabled (applicationShouldRestoreApplicationState false, NSQuitAlwaysKeepsWindows false) — restored empty plan windows were confusing — cost: windows do not come back after relaunch

## Final review düzeltmeleri

- C1 edits during stage 2 reverted / critical re-approved — editsAreRejectedWhileStage2Runs RED→GREEN, app 49/49, core 145/145
- I1 İptal/window close did not stop stage 2 — cancelStopsStage2 RED→GREEN, app 49/49
- I2 review blind save resurrected applied plan / overwrote changes — reviewDoesNotResurrectAppliedPlan + reviewKeepsChangesMadeWhileItRan RED→GREEN, core 145/145
- I3 group header touched pending items of the same category — groupHeaderOnlyTouchesItsGroup RED→GREEN, app 49/49
- I4 rescan resumed old checkpoint — rescanStartsFreshAndCancelledScanCanResume + makePlanWithoutResumeIgnoresCheckpoint RED→GREEN
- I5 previous undo leaked into next result — nextApplyClearsPreviousUndo RED→GREEN
- I6 edited pending row jumped to Hazır — editedPendingItemStaysInPendingSection RED→GREEN
- I7 rows disagree with plan after failed edit — failedEditBumpsRevision RED→GREEN (rows re-sync on revision)
- I8 (safety part) confirmation sheet could differ from what moves — applyRefusesWhenApprovalsChangedElsewhere RED→GREEN
- I9 main-thread reads — structural: latestReady / RunLog.list via @concurrent helpers, settings cached per session (no failing test possible for main-thread placement); existing suites green
- (regraded) test host touched real data dir — appTestsUseTemporaryDataDirectory RED→GREEN (scheme env TRIMLY_DATA_DIR)
- (regraded) second concurrent scan during initial health check — rescanIsIgnoredWhileStarting RED (hang) →GREEN
- (regraded) invalid link silently ignored — errorMessages RED→GREEN; alert verified manually via AX ("Bağlantı açılamadı / Klasör bulunamadı: …")
- (regraded) rescan reused stale Ollama health — rescanRefreshesOllamaHealth RED→GREEN

## Ertelenen minor bulgular

- Geri Al has no confirmation dialog and no in-flight guard (double click → second undo attempt)
- SettingsModel loads settings once; a CLI `trimly settings` change is overwritten by the next GUI change
- clearing a description is a no-op
- start window recent runs refresh only when the window appears
- after undo the footer still says "Uygulandı"; history undo summary omits skip reasons
- result sheet presented in the same turn ApplySheet dismisses — verify manually ("Sonucu göster" fallback exists)
- ApplySheet/edits decode+encode the whole plan per change

## Elle doğrulama ve olay notu

- Task 3: manual — cold URL launch opened only the "Plan" window (no start window), app kept running; window showed the decoded path with space + Turkish chars.
- Task 4: manual — start window AX tree: title, subtitle, 3 shortcuts, "Son işlemler" group, Geçmiş + Ayarlar buttons, "Ollama: Hazır" (live Ollama).
- Task 7: INCIDENT — during manual AX verification (app launched with TRIMLY_DATA_DIR=<tmp>), a plan window for ~/Desktop appeared at 10:45:06 and that plan was applied at 10:45:30 (run r-20261121-104530): 14 items moved inside ~/Desktop into 6 new category folders, all present at targets, nothing deleted. Cause unknown (executor only read the AX tree; osascript lost Accessibility permission right after). Journal backed up to .superpowers/incident-desktop-run-backup/data. STOPPED to ask the user before any undo or further UI automation.
- Task 7: INCIDENT resolved — the user confirmed they clicked the Masaüstü shortcut, approved items and confirmed Uygula themselves. App behaved as designed. Desktop left organized (no undo). Run journal kept at .superpowers/incident-desktop-run-backup/data (offered import into real data dir).
- Task 7: manual — plan window AX tree (before the user's session): pending rows render checkbox, status icon, name, "→ target", category popup, detail line ("klasör, elle onay gerekir · güven 0.60 · karar: kural"); user exercised Masaüstü shortcut → plan → approvals → ApplySheet → apply end to end.
- Task 8: manual — settings window not visually checked (osascript Accessibility permission revoked during the Task 7 incident); behaviour covered by SettingsModelTests.
- Task 9: manual — S1 ✓ (after fix), S2 ✓, S3 ✓ (inProgress 2/12 → resumed same id → ready), S4 ✓; report docs/superpowers/reports/2026-11-21-phase2-manual-verification.md
- Final: Ruling: declined "INCIDENT" — user-confirmed deliberate use; reviewer confirmed only ApplySheet→Uygula moves files forward — cost: none
