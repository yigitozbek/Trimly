import Foundation

public enum DefaultCategories {
    public static let all: [Category] = [
        make("screenshots", "Ekran-Goruntuleri", "Ekran-Goruntusu", "Screenshots", "Screenshot"),
        make("screenRecordings", "Ekran-Kayitlari", "Ekran-Kaydi", "Screen-Recordings", "Screen-Recording"),
        make("photos", "Fotograflar", "Fotograf", "Photos", "Photo"),
        make("images", "Gorseller", "Gorsel", "Images", "Image"),
        make("videos", "Videolar", "Video", "Videos", "Video"),
        make("audio", "Ses", "Ses", "Audio", "Audio"),
        make("documents", "Belgeler", "Belge", "Documents", "Document"),
        make("invoices", "Faturalar", "Fatura", "Invoices", "Invoice"),
        make("contracts", "Sozlesmeler", "Sozlesme", "Contracts", "Contract"),
        make("officialDocs", "Resmi-Evrak", "Evrak", "Official-Documents", "Official"),
        make("health", "Saglik", "Saglik", "Health", "Health"),
        make("books", "Kitaplar-Makaleler", "Kitap", "Books-Papers", "Book"),
        make("spreadsheets", "Tablolar", "Tablo", "Spreadsheets", "Spreadsheet"),
        make("presentations", "Sunumlar", "Sunum", "Presentations", "Presentation"),
        make("data", "Veri", "Veri", "Data", "Data"),
        make("code", "Kod", "Kod", "Code", "Code"),
        make("design", "Tasarim", "Tasarim", "Design", "Design"),
        make("archives", "Arsivler", "Arsiv", "Archives", "Archive"),
        make("installers", "Kurulum-Dosyalari", "Kurulum", "Installers", "Installer"),
        make("certificates", "Sertifika-Anahtar", "Sertifika", "Certificates-Keys", "Certificate"),
        make("fonts", "Yazi-Tipleri", "Yazi-Tipi", "Fonts", "Font"),
        make("other", "Diger", "Diger", "Other", "Other")
    ]

    private static func make(_ id: String, _ folderTR: String, _ tagTR: String, _ folderEN: String, _ tagEN: String) -> Category {
        Category(id: id, folder: LocalizedText(tr: folderTR, en: folderEN), tag: LocalizedText(tr: tagTR, en: tagEN))
    }
}
