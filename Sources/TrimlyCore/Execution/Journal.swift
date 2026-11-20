import Foundation

/// Append-only JSONL log of one run. Every line is fsync'ed before the file operation it describes proceeds,
/// so a crash leaves at worst a `pending` line that `Recovery` can resolve against the disk.
public struct Journal: Sendable {
    public let url: URL
    public private(set) var entries: [JournalEntry]
    /// Byte length of the valid prefix when the last line is torn (crash/disk full mid-write); cut before the next append.
    private var tornTailOffset: UInt64?

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private init(url: URL, entries: [JournalEntry], tornTailOffset: UInt64? = nil) {
        self.url = url
        self.entries = entries
        self.tornTailOffset = tornTailOffset
    }

    public static func create(at url: URL, header: JournalEntry) throws -> Journal {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        var journal = Journal(url: url, entries: [])
        var first = header
        first.seq = 0
        try journal.write(first)
        return journal
    }

    /// A torn final line is treated as never written: a torn `pending` means the move never started, and a torn
    /// state line leaves a `pending` entry that `Recovery` resolves from disk. Corruption elsewhere still throws.
    public static func open(at url: URL) throws -> Journal {
        let data = try Data(contentsOf: url)
        var entries: [JournalEntry] = []
        var validLength = 0
        var lineStart = 0
        var torn = false
        while lineStart < data.count {
            let lineEnd = data[lineStart...].firstIndex(of: 0x0A) ?? data.count
            let line = data[lineStart..<lineEnd]
            let isLast = lineEnd >= data.count - 1
            if line.isEmpty == false {
                do {
                    entries.append(try JSONCoding.decoder.decode(JournalEntry.self, from: Data(line)))
                } catch where isLast {
                    torn = true
                    break
                }
            }
            lineStart = lineEnd + 1
            validLength = min(lineStart, data.count)
        }
        let endsWithNewline = data.last == 0x0A
        let cut: UInt64? = torn || (data.isEmpty == false && endsWithNewline == false) ? UInt64(validLength) : nil
        return Journal(url: url, entries: entries, tornTailOffset: cut)
    }

    /// Assigns the next `seq`, writes the line, syncs it to disk and returns the `seq`.
    @discardableResult
    public mutating func append(_ entry: JournalEntry) throws -> Int {
        var line = entry
        line.seq = entries.count
        try write(line)
        return line.seq
    }

    /// The operation's own state, overridden by the last state-change line that refers to it.
    public func effectiveState(of seq: Int) -> JournalState? {
        if let update = entries.last(where: { $0.isStateUpdate && $0.ref == seq }) {
            return update.state
        }
        return entries.first { $0.seq == seq }?.state
    }

    private mutating func write(_ entry: JournalEntry) throws {
        var data = try Self.encoder.encode(entry)
        data.append(0x0A)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        if let tornTailOffset {
            try handle.truncate(atOffset: tornTailOffset)
            self.tornTailOffset = nil
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
        entries.append(entry)
    }
}
