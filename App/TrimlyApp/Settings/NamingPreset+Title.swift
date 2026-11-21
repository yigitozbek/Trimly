import TrimlyCore

extension NamingPreset {
    var title: String {
        switch self {
        case .dateCategoryDescription: "Tarih + kategori + açıklama"
        case .categoryDescription: "Kategori + açıklama"
        case .dateDescription: "Tarih + açıklama"
        case .originalNormalized: "Orijinal ad (düzeltilmiş)"
        case .keepOriginal: "Adı değiştirme"
        }
    }
}
