struct CategoryCount: Equatable, Identifiable {
    let title: String
    let count: Int

    var id: String { title }
}
