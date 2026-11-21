/// What a kept folder carries along when it moves as one unit.
struct FolderCoverage: Equatable {
    let count: Int
    let critical: Int
    /// The scan listed the folder's contents; otherwise `count` says nothing about what is inside.
    let listed: Bool
}
