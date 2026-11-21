import Foundation

/// Resolves `pending` journal lines left by a crash by looking at where the files actually are.
public enum Recovery {
    @discardableResult
    public static func recover(journalAt url: URL) throws -> Int {
        var journal = try Journal.open(at: url)
        let fm = FileManager.default
        var fixed = 0
        for entry in journal.entries where entry.op != nil && journal.effectiveState(of: entry.seq) == .pending {
            let completed: Bool
            switch entry.op {
            case .move:
                guard let from = entry.from, let to = entry.to else { continue }
                completed = fm.fileExists(atPath: to) && fm.fileExists(atPath: from) == false
            case .undo:
                guard let original = entry.ref.flatMap({ ref in journal.entries.first { $0.seq == ref } }) else {
                    continue
                }
                switch original.op {
                case .move:
                    guard let from = original.from, let to = original.to else { continue }
                    completed = fm.fileExists(atPath: from) && fm.fileExists(atPath: to) == false
                case .tag:
                    guard let path = original.path, let previous = original.previousTags else { continue }
                    completed = FinderTags.sameSet(FinderTags.read(URL(filePath: path)), previous)
                default:
                    continue
                }
            case .mkdir:
                guard let path = entry.path else { continue }
                completed = fm.fileExists(atPath: path)
            case .rmdir:
                guard let path = entry.path else { continue }
                completed = fm.fileExists(atPath: path) == false
            case .tag:
                guard let path = entry.path, let tags = entry.tags else { continue }
                completed = FinderTags.sameSet(FinderTags.read(URL(filePath: path)), tags)
            case nil:
                continue
            }
            try journal.append(JournalEntry(seq: -1, ref: entry.seq, state: completed ? .done : .failed, message: "Kurtarma"))
            fixed += 1
        }
        return fixed
    }

    @discardableResult
    public static func recoverAll(in directory: DataDirectory) throws -> Int {
        // A live apply/undo (app or CLI) holds the lock and may have legitimately pending lines: leave them alone.
        guard let lock = try? DataLock.acquire(in: directory) else {
            return 0
        }
        return withExtendedLifetime(lock) {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.runsURL.path)) ?? []
            // One unreadable journal must not block every command; it is skipped and left for inspection.
            return names.filter { $0.hasSuffix(".jsonl") }.reduce(0) { total, name in
                total + ((try? recover(journalAt: directory.runsURL.appending(path: name))) ?? 0)
            }
        }
    }
}
