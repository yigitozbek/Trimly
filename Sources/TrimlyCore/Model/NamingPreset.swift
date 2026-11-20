import Foundation

public enum NamingPreset: String, Codable, CaseIterable, Sendable {
    case dateCategoryDescription
    case categoryDescription
    case dateDescription
    case originalNormalized
    case keepOriginal
}
