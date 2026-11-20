import Testing
@testable import TrimlyCore

struct CriticalDetectorTests {
    let detector = CriticalDetector(settings: Settings())

    @Test(arguments: ["cert.der", "dump.SQL", "iade-talebi.udf", "ISTIRAHAT RAPORLARI.pdf", "kimlik_on.jpg", "TC_Kimlik.png", "Şifreler.txt", "maaş bordrosu.xlsx", "release.keystore", "upload.jks"])
    func critical(_ name: String) {
        #expect(detector.isCritical(.stub(name)))
    }

    @Test(arguments: ["etc-notes.txt", "rapido.pdf", "tatil.jpg"])
    func notCritical(_ name: String) {
        #expect(detector.isCritical(.stub(name)) == false)
    }
}
