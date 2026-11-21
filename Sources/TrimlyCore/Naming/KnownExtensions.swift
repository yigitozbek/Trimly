import Foundation

/// Every extension the rule engine knows about; used to strip leaked extensions from descriptions.
public enum KnownExtensions {
    public static let all: Set<String> = [
        // photos & images
        "heic", "heif", "dng", "cr2", "nef", "arw", "raw", "png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "tiff", "tif",
        // video & audio
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "3gp",
        "mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "aif", "opus",
        // archives & installers
        "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst", "lz4",
        "dmg", "pkg", "mpkg", "iso", "exe", "msi", "apk", "ipa", "jar", "aab", "jnlp",
        // code
        "swift", "py", "js", "ts", "tsx", "jsx", "java", "kt", "c", "h", "cpp", "hpp", "m", "mm", "go", "rs", "rb", "php",
        "sh", "zsh", "html", "htm", "css", "scss", "ipynb",
        // data & spreadsheets & presentations
        "json", "csv", "geojson", "xml", "yaml", "yml", "plist", "tsv", "parquet", "sql", "sqlite", "db",
        "xlsx", "xls", "numbers", "ods", "pptx", "ppt", "odp", "key",
        // documents & design & fonts & books
        "pdf", "doc", "docx", "txt", "md", "rtf", "pages", "odt", "eml", "msg",
        "psd", "pxd", "sketch", "fig", "ai", "xd", "afdesign", "afphoto", "indd", "eps",
        "ttf", "otf", "woff", "woff2", "epub", "mobi", "azw3", "djvu",
        // official & certificates
        "udf", "der", "pem", "cer", "crt", "p12", "pfx", "mobileprovision", "kdbx", "env", "keystore", "jks", "p8"
    ]
}
