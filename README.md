# Trimly

Local, AI-assisted, safe file and folder organizer for macOS, written in Swift.

Trimly tidies messy folders like `~/Desktop` and `~/Downloads`. Deterministic rules classify most files; a local LLM via [Ollama](https://ollama.com) handles only the ambiguous ones. Nothing leaves your Mac, nothing moves until you've seen a preview and approved it, and every applied run can be undone.

## Features

- **Preview before anything moves.** `plan` is read-only and shows current name → target folder / new name, plus the confidence and the reason for each item.
- **Layered classification.** Filename patterns and extension rules decide first. Only uncertain items go to a small local model (stage 1). A larger model (stage 2) is used only for low-confidence or critical items, and only when you ask for it.
- **Journaled moves with undo.** Every operation is written to a JSONL journal before it runs. `undo` reverses a whole run. If a run is interrupted, Trimly recovers it the next time it starts.
- **Never deletes or overwrites.** Trash candidates (old installers, stale partial downloads, duplicates, empty and temp files) go to the macOS Trash one at a time, and that step is journaled and undoable too.
- **Critical file protection.** Certificates, keys, databases, `.env` files and names like `pasaport` or `password` are flagged as critical. Their content is never sent to the LLM, and no automatic step (rules, LLM or bulk approve) can approve them.
- **Leaves projects alone.** Folders containing `.git`, `package.json`, `Package.swift`, `Cargo.toml` and similar markers are skipped, as are hidden files, `.app` bundles, partial downloads and recently modified items.
- **Nested folders.** Scans up to 5 levels deep by default. A folder that is mostly one category is moved as a unit (`keep`); a mixed folder has its contents organized one by one (`distribute`).
- **Finder tags.** Moved items get their category tag. A tag-only mode writes tags without moving anything.
- **Naming presets.** Choose date + category + description (`2025-03-14_Ekran-Goruntusu_10-22-31.png`), category + description, date + description, a cleaned-up version of the original name, or the original name unchanged.
- **Six languages for category names:** Turkish (the default), English, Japanese, French, Italian and Korean.

## Requirements

- macOS 14 or later
- Swift 6.2 toolchain (Xcode 26 or later)
- [Ollama](https://ollama.com) running on `localhost:11434`. This is optional: without it, or with `--no-llm`, Trimly uses rules only.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), only if you build the macOS app

Default models:

```sh
ollama pull qwen3:4b          # stage 1
ollama pull ministral-3:14b   # stage 2 (review)
```

## Build and test

```sh
swift build                              # TrimlyCore + trimly CLI
swift test                               # all TrimlyCore tests (Swift Testing)
swift test --filter NormalizerTests      # one suite
zsh scripts/smoke.sh                     # end-to-end CLI smoke test in a temp folder
```

The smoke script runs `plan → apply → undo` in a throwaway directory, covering nested folders, tag-only mode and trash. It never touches real user folders.

### macOS app

```sh
cd App
xcodegen generate
open Trimly.xcodeproj    # run the TrimlyApp scheme
```

The app isn't sandboxed and asks for Desktop, Downloads and Documents access the first time it needs each one. You can open it on a folder with a URL: `open "trimly://organize?path=/Users/me/Downloads"`.

## CLI usage

The flow is: **plan** (preview) → **set / approve** (decide) → **apply** (journaled move) → **undo**.

```sh
trimly plan ~/Downloads                   # scan and save a preview plan; touches nothing
trimly plan ~/Downloads --no-llm          # rules only
trimly review <plan>                      # re-check review/critical items with the stage-2 model
trimly approve <plan> --min-confidence 0.8
trimly approve <plan> --category invoices --folders
trimly set <plan> <item> --category documents --name "Kira Ocak" --approve   # or --reject
trimly set <plan> <item> --mode keep      # move a folder as one unit (or: distribute)
trimly apply <plan>                       # asks for confirmation; --yes skips it
trimly trash <plan> <item>                # move one trash candidate to the Trash
trimly runs                               # history of applied runs
trimly undo [<run>]                       # undo a run (default: the most recent one)
trimly settings [--path] [--reset]
```

The plan ID is printed on the last line of `plan` output. Item IDs are the 8-character codes in the plan table. Every command accepts `--data-dir <path>` to use a data directory other than the default. CLI output is in Turkish.

## Data and settings

The app and the CLI share `~/Library/Application Support/Trimly/`:

```
settings.json        # preferences (missing keys fall back to defaults)
plans/<planId>.json  # saved previews
runs/<runId>.jsonl   # journals used for undo and crash recovery
```

Main settings:

| Key | Default | Meaning |
|---|---|---|
| `targetMode` | `inPlace` | `inPlace` (category folders inside the scanned folder), `central` (move into `archiveRoot`), `tagOnly` |
| `archiveRoot` | `~/Documents/Arsiv` | Target for `central` mode |
| `namingPreset` | `dateCategoryDescription` | File naming preset |
| `categoryLanguage` | `tr` | `tr`, `en`, `ja`, `fr`, `it`, `ko` |
| `stage1Model` / `stage2Model` | `qwen3:4b` / `ministral-3:14b` | Ollama models |
| `confidenceThreshold` | `0.75` | Below this, an item needs review |
| `scanDepth` | `5` | Folder levels to scan (1 = top level only) |
| `recentMinutes` | `60` | Skip items modified within this window |
| `addCategoryTags` | `true` | Add a Finder tag to moved items |
| `removeEmptyFolders` | `false` | Remove folders a run leaves empty (journaled) |

`trimly settings` prints the full list.

## Project layout

```
Sources/TrimlyCore/   engine: Scan → Rules → LLM → Naming → Planning → Execution
Sources/trimly/       CLI (swift-argument-parser)
Tests/TrimlyCoreTests/
App/                  SwiftUI app (XcodeGen project.yml, TrimlyApp, TrimlyAppTests)
scripts/smoke.sh      CLI end-to-end test
```

## Safety rules for contributors

- User files are never deleted or overwritten. Moves happen only through the journaled `Executor`.
- Tests never touch the real `~/Desktop` or `~/Downloads`; use temp directories and `--data-dir`.
- On real data, run only `trimly plan`. Never run `apply` without the user's explicit approval.
- Critical file content never goes to the LLM, and no automatic step may approve a critical item.
