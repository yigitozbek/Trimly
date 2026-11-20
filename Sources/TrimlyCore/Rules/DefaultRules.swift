import Foundation

public enum DefaultRules {
    /// Keyed by the last extension component (`tar.gz` → `gz`).
    public static let extensionMap: [String: (categoryID: String, strength: RuleStrength)] = {
        var map: [String: (categoryID: String, strength: RuleStrength)] = [:]
        func add(_ category: String, _ strength: RuleStrength, _ extensions: String) {
            for ext in extensions.split(separator: " ") {
                map[String(ext)] = (category, strength)
            }
        }
        add("photos", .decisive, "heic heif dng cr2 nef arw raw")
        add("images", .decisive, "png jpg jpeg gif webp bmp svg tiff tif")
        add("videos", .decisive, "mp4 mov m4v avi mkv webm wmv flv 3gp")
        add("audio", .decisive, "mp3 m4a wav aac flac ogg aiff aif opus")
        add("archives", .weak, "zip")
        add("archives", .decisive, "rar 7z tar gz tgz bz2 xz")
        add("installers", .decisive, "dmg pkg mpkg iso exe msi apk ipa")
        add("installers", .weak, "jar")
        add("code", .decisive, "swift py js ts tsx jsx java kt c h cpp hpp m mm go rs rb php sh zsh html css scss ipynb")
        add("data", .weak, "json")
        add("spreadsheets", .weak, "csv")
        add("data", .decisive, "geojson xml yaml yml plist tsv parquet sql sqlite db")
        add("spreadsheets", .decisive, "xlsx xls numbers ods")
        add("presentations", .decisive, "pptx ppt odp")
        add("documents", .weak, "pdf doc docx txt md rtf pages odt")
        add("design", .decisive, "psd pxd sketch fig ai xd afdesign afphoto indd eps")
        add("fonts", .decisive, "ttf otf woff woff2")
        add("books", .decisive, "epub mobi azw3 djvu")
        add("officialDocs", .decisive, "udf")
        add("certificates", .decisive, "der pem cer crt p12 pfx mobileprovision kdbx env")
        return map
    }()
}
