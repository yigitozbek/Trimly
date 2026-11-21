import Foundation

public enum DefaultCategories {
    public static let all: [Category] = [
        make(
            "screenshots",
            folder: ("Ekran-Goruntuleri", "Screenshots", "スクリーンショット", "Captures-Ecran", "Screenshot", "스크린샷"),
            tag: ("Ekran-Goruntusu", "Screenshot", "スクリーンショット", "Capture", "Screenshot", "스크린샷")
        ),
        make(
            "screenRecordings",
            folder: ("Ekran-Kayitlari", "Screen-Recordings", "画面収録", "Enregistrements-Ecran", "Registrazioni-Schermo", "화면-녹화"),
            tag: ("Ekran-Kaydi", "Screen-Recording", "画面収録", "Enregistrement", "Registrazione", "화면녹화")
        ),
        make(
            "photos",
            folder: ("Fotograflar", "Photos", "写真", "Photos", "Foto", "사진"),
            tag: ("Fotograf", "Photo", "写真", "Photo", "Foto", "사진")
        ),
        make(
            "images",
            folder: ("Gorseller", "Images", "画像", "Images", "Immagini", "이미지"),
            tag: ("Gorsel", "Image", "画像", "Image", "Immagine", "이미지")
        ),
        make(
            "videos",
            folder: ("Videolar", "Videos", "動画", "Videos", "Video", "동영상"),
            tag: ("Video", "Video", "動画", "Video", "Video", "동영상")
        ),
        make(
            "audio",
            folder: ("Ses", "Audio", "音声", "Audio", "Audio", "오디오"),
            tag: ("Ses", "Audio", "音声", "Audio", "Audio", "오디오")
        ),
        make(
            "documents",
            folder: ("Belgeler", "Documents", "書類", "Documents", "Documenti", "문서"),
            tag: ("Belge", "Document", "書類", "Document", "Documento", "문서")
        ),
        make(
            "invoices",
            folder: ("Faturalar", "Invoices", "請求書", "Factures", "Fatture", "청구서"),
            tag: ("Fatura", "Invoice", "請求書", "Facture", "Fattura", "청구서")
        ),
        make(
            "contracts",
            folder: ("Sozlesmeler", "Contracts", "契約", "Contrats", "Contratti", "계약"),
            tag: ("Sozlesme", "Contract", "契約", "Contrat", "Contratto", "계약")
        ),
        make(
            "officialDocs",
            folder: ("Resmi-Evrak", "Official-Documents", "公的書類", "Documents-Officiels", "Documenti-Ufficiali", "공문서"),
            tag: ("Evrak", "Official", "公的", "Officiel", "Ufficiale", "공문서")
        ),
        make(
            "health",
            folder: ("Saglik", "Health", "健康", "Sante", "Salute", "건강"),
            tag: ("Saglik", "Health", "健康", "Sante", "Salute", "건강")
        ),
        make(
            "books",
            folder: ("Kitaplar-Makaleler", "Books-Papers", "書籍-論文", "Livres-Articles", "Libri-Articoli", "책-논문"),
            tag: ("Kitap", "Book", "書籍", "Livre", "Libro", "책")
        ),
        make(
            "spreadsheets",
            folder: ("Tablolar", "Spreadsheets", "表計算", "Tableurs", "Fogli-di-Calcolo", "스프레드시트"),
            tag: ("Tablo", "Spreadsheet", "表計算", "Tableur", "Foglio", "스프레드시트")
        ),
        make(
            "presentations",
            folder: ("Sunumlar", "Presentations", "プレゼン", "Presentations", "Presentazioni", "프레젠테이션"),
            tag: ("Sunum", "Presentation", "プレゼン", "Presentation", "Presentazione", "프레젠테이션")
        ),
        make(
            "data",
            folder: ("Veri", "Data", "データ", "Donnees", "Dati", "데이터"),
            tag: ("Veri", "Data", "データ", "Donnees", "Dati", "데이터")
        ),
        make(
            "code",
            folder: ("Kod", "Code", "コード", "Code", "Codice", "코드"),
            tag: ("Kod", "Code", "コード", "Code", "Codice", "코드")
        ),
        make(
            "design",
            folder: ("Tasarim", "Design", "デザイン", "Design", "Design", "디자인"),
            tag: ("Tasarim", "Design", "デザイン", "Design", "Design", "디자인")
        ),
        make(
            "archives",
            folder: ("Arsivler", "Archives", "アーカイブ", "Archives", "Archivi", "아카이브"),
            tag: ("Arsiv", "Archive", "アーカイブ", "Archive", "Archivio", "아카이브")
        ),
        make(
            "installers",
            folder: ("Kurulum-Dosyalari", "Installers", "インストーラ", "Installateurs", "Installer", "설치-파일"),
            tag: ("Kurulum", "Installer", "インストーラ", "Installateur", "Installer", "설치")
        ),
        make(
            "certificates",
            folder: ("Sertifika-Anahtar", "Certificates-Keys", "証明書-鍵", "Certificats-Cles", "Certificati-Chiavi", "인증서-키"),
            tag: ("Sertifika", "Certificate", "証明書", "Certificat", "Certificato", "인증서")
        ),
        make(
            "fonts",
            folder: ("Yazi-Tipleri", "Fonts", "フォント", "Polices", "Font", "글꼴"),
            tag: ("Yazi-Tipi", "Font", "フォント", "Police", "Font", "글꼴")
        ),
        make(
            "other",
            folder: ("Diger", "Other", "その他", "Autres", "Altro", "기타"),
            tag: ("Diger", "Other", "その他", "Autre", "Altro", "기타")
        )
    ]

    private static func make(
        _ id: String,
        folder: (tr: String, en: String, ja: String, fr: String, it: String, ko: String),
        tag: (tr: String, en: String, ja: String, fr: String, it: String, ko: String)
    ) -> Category {
        Category(
            id: id,
            folder: LocalizedText(tr: folder.tr, en: folder.en, ja: folder.ja, fr: folder.fr, it: folder.it, ko: folder.ko),
            tag: LocalizedText(tr: tag.tr, en: tag.en, ja: tag.ja, fr: tag.fr, it: tag.it, ko: tag.ko)
        )
    }
}
