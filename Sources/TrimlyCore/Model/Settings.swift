import Foundation

public struct Settings: Codable, Equatable, Sendable {
    // Naming
    public var namingPreset: NamingPreset = .dateCategoryDescription
    public var categoryLanguage: Language = .tr

    // Target
    public var targetMode: TargetMode = .inPlace
    public var archiveRoot = "~/Documents/Arsiv"
    public var yearSubfolders = false

    // Model
    public var llmEnabled = true
    public var providerURL = "http://localhost:11434"
    public var stage1Model = "qwen3:4b"
    public var stage2Model = "ministral-3:14b"
    public var confidenceThreshold = 0.75
    public var batchSize = 10
    public var contentPreview = true
    public var timeoutSeconds = 60.0
    public var keepAlive = "2m"

    // Ignore
    public var ignoreHidden = true
    public var ignoreApps = true
    public var recentMinutes = 60
    public var projectMarkers = [
        ".git", "package.json", "node_modules", "Package.swift", "*.xcodeproj", "Cargo.toml", "pyproject.toml",
        "go.mod", "pom.xml", "build.gradle", "Gemfile", "composer.json", ".venv", "venv", "Pods"
    ]
    public var projectFolderNames = ["build", "dist", "target", "DerivedData", "node_modules"]
    public var ignoreGlobs = ["*.photoslibrary", "*.musiclibrary", "*.fcpbundle", "*.lrlibrary"]

    // Critical
    public var criticalExtensions = [
        "der", "pem", "cer", "key", "p12", "pfx", "mobileprovision", "env", "sql", "sqlite", "db", "kdbx", "udf",
        "keystore", "jks", "p8"
    ]
    public var criticalKeywords = [
        "kimlik", "nufus", "pasaport", "tc", "ehliyet", "saglik", "rapor", "recete", "tahlil", "bordro", "maas",
        "iban", "sifre", "password", "vekaletname"
    ]

    // Categories
    public var categories = DefaultCategories.all

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        namingPreset = try c.decodeIfPresent(NamingPreset.self, forKey: .namingPreset) ?? d.namingPreset
        categoryLanguage = try c.decodeIfPresent(Language.self, forKey: .categoryLanguage) ?? d.categoryLanguage
        targetMode = try c.decodeIfPresent(TargetMode.self, forKey: .targetMode) ?? d.targetMode
        archiveRoot = try c.decodeIfPresent(String.self, forKey: .archiveRoot) ?? d.archiveRoot
        yearSubfolders = try c.decodeIfPresent(Bool.self, forKey: .yearSubfolders) ?? d.yearSubfolders
        llmEnabled = try c.decodeIfPresent(Bool.self, forKey: .llmEnabled) ?? d.llmEnabled
        providerURL = try c.decodeIfPresent(String.self, forKey: .providerURL) ?? d.providerURL
        stage1Model = try c.decodeIfPresent(String.self, forKey: .stage1Model) ?? d.stage1Model
        stage2Model = try c.decodeIfPresent(String.self, forKey: .stage2Model) ?? d.stage2Model
        confidenceThreshold = try c.decodeIfPresent(Double.self, forKey: .confidenceThreshold) ?? d.confidenceThreshold
        batchSize = try c.decodeIfPresent(Int.self, forKey: .batchSize) ?? d.batchSize
        contentPreview = try c.decodeIfPresent(Bool.self, forKey: .contentPreview) ?? d.contentPreview
        timeoutSeconds = try c.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? d.timeoutSeconds
        keepAlive = try c.decodeIfPresent(String.self, forKey: .keepAlive) ?? d.keepAlive
        ignoreHidden = try c.decodeIfPresent(Bool.self, forKey: .ignoreHidden) ?? d.ignoreHidden
        ignoreApps = try c.decodeIfPresent(Bool.self, forKey: .ignoreApps) ?? d.ignoreApps
        recentMinutes = try c.decodeIfPresent(Int.self, forKey: .recentMinutes) ?? d.recentMinutes
        projectMarkers = try c.decodeIfPresent([String].self, forKey: .projectMarkers) ?? d.projectMarkers
        projectFolderNames = try c.decodeIfPresent([String].self, forKey: .projectFolderNames) ?? d.projectFolderNames
        ignoreGlobs = try c.decodeIfPresent([String].self, forKey: .ignoreGlobs) ?? d.ignoreGlobs
        criticalExtensions = try c.decodeIfPresent([String].self, forKey: .criticalExtensions) ?? d.criticalExtensions
        criticalKeywords = try c.decodeIfPresent([String].self, forKey: .criticalKeywords) ?? d.criticalKeywords
        categories = try c.decodeIfPresent([Category].self, forKey: .categories) ?? d.categories
    }

    public func category(id: String) -> Category? {
        categories.first { $0.id == id }
    }

    /// Finds a category by its folder name in either language, ignoring case.
    public func category(forFolderName name: String) -> Category? {
        let needle = name.lowercased()
        return categories.first { $0.folder.tr.lowercased() == needle || $0.folder.en.lowercased() == needle }
    }

    /// Folder and tag names in both languages; used to strip category words from descriptions.
    public func categoryTerms(_ category: Category) -> [String] {
        [category.folder.tr, category.tag.tr, category.folder.en, category.tag.en]
    }

    /// Lowercased folder names of every category in both languages.
    public var allCategoryFolderNames: Set<String> {
        Set(categories.flatMap { [$0.folder.tr.lowercased(), $0.folder.en.lowercased()] })
    }
}
