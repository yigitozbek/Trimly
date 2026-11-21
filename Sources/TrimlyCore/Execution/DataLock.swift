import Foundation

/// Exclusive advisory lock on the data directory (`<root>/lock`) so the app and the CLI never apply or undo
/// at the same time. Released when the object is deallocated; hold it with `withExtendedLifetime`.
public final class DataLock {
    private let descriptor: Int32

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    /// Never waits: throws `DataLockError.busy` if another process (or another open in this one) holds it.
    public static func acquire(in directory: DataDirectory) throws -> DataLock {
        try FileManager.default.createDirectory(at: directory.root, withIntermediateDirectories: true)
        let path = directory.root.appending(path: "lock", directoryHint: .notDirectory).path
        let descriptor = open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else {
            throw CocoaError(.fileWriteNoPermission)
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw DataLockError.busy
        }
        return DataLock(descriptor: descriptor)
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
