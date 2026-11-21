import Foundation

/// Plans live as `plans/<id>.json` in the data directory.
public struct PlanStore: Sendable {
    private static let resumeWindow: TimeInterval = 24 * 3600
    private let directory: DataDirectory

    public init(directory: DataDirectory) {
        self.directory = directory
    }

    public func save(_ plan: Plan) throws {
        try FileManager.default.createDirectory(at: directory.plansURL, withIntermediateDirectories: true)
        try JSONCoding.encoder.encode(plan).write(to: url(for: plan.id), options: .atomic)
    }

    public func load(id: String) throws -> Plan {
        let url = url(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PlanError.notFound(id)
        }
        return try JSONCoding.decoder.decode(Plan.self, from: Data(contentsOf: url))
    }

    public func exists(id: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    /// Newest first; unreadable files are ignored.
    public func list() throws -> [Plan] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.plansURL.path)) ?? []
        return names
            .filter { $0.hasSuffix(".json") }
            .compactMap { try? load(id: String($0.dropLast(5))) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// An unfinished plan for the same root started less than 24 hours ago.
    public func latestResumable(root: URL, now: Date) throws -> Plan? {
        try list().first { plan in
            plan.state == .inProgress
                && TargetResolver.samePath(plan.root, root)
                && plan.createdAt > now.addingTimeInterval(-Self.resumeWindow)
        }
    }

    /// A finished, not yet applied plan for the same root from the last 24 hours (e.g. started in the CLI).
    public func latestReady(root: URL, now: Date) throws -> Plan? {
        try list().first { plan in
            plan.state == .ready
                && TargetResolver.samePath(plan.root, root)
                && plan.createdAt > now.addingTimeInterval(-Self.resumeWindow)
        }
    }

    /// Runs a short read-modify-write under the data-directory lock (the same lock apply/undo hold),
    /// so concurrent writers (app, CLI, stage 2) never overwrite each other's plan changes.
    public func withLock<T>(_ body: () throws -> T) throws -> T {
        let lock = try DataLock.acquire(in: directory)
        return try withExtendedLifetime(lock) {
            try body()
        }
    }

    private func url(for id: String) -> URL {
        directory.plansURL.appending(path: "\(id).json", directoryHint: .notDirectory)
    }
}
