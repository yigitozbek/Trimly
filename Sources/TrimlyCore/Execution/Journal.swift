import Foundation

/// Append-only JSONL log of one run. Every line is fsync'ed before the file operation it describes proceeds,
/// so a crash leaves at worst a `pending` line that `Recovery` can resolve against the disk.
public struct Journal: Sendable {
    public let url: URL
    public private(set) var entries: [JournalEntry]

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private init(url: URL, entries: [JournalEntry]) {
        self.url = url
        self.entries = entries
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

    public static func open(at url: URL) throws -> Journal {
        let text = try String(contentsOf: url, encoding: .utf8)
        let entries = try text.split(separator: "\n").map { line in
            try JSONCoding.decoder.decode(JournalEntry.self, from: Data(line.utf8))
        }
        return Journal(url: url, entries: entries)
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
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
        entries.append(entry)
    }
}
