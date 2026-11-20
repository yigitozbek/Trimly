import Foundation

public enum DateResolver {
    private enum Order { case ymd, dmy }

    /// Digit runs must not touch other digits; `(?:^|\D)` stands in for the lookbehind Swift Regex lacks.
    private static var patterns: [(Regex<(Substring, Substring, Substring, Substring)>, Order)] {
        [
            (/(?:^|\D)(\d{4})[-_](\d{2})[-_](\d{2})(?!\d)/, .ymd),
            (/(?:^|\D)(\d{4})(\d{2})(\d{2})(?!\d)/, .ymd),
            (/(?:^|\D)(\d{2})\.(\d{2})\.(\d{4})(?!\d)/, .dmy)
        ]
    }

    /// First valid calendar date written in the name (`YYYY-MM-DD`, `YYYY_MM_DD`, `YYYYMMDD`, `DD.MM.YYYY`), at local midnight.
    public static func dateFromName(_ name: String, calendar: Calendar = .current) -> Date? {
        for (regex, order) in patterns {
            for match in name.matches(of: regex) {
                let (_, a, b, c) = match.output
                let (year, month, day) = order == .ymd ? (Int(a), Int(b), Int(c)) : (Int(c), Int(b), Int(a))
                if let year, let month, let day, let date = validDate(year: year, month: month, day: day, calendar: calendar) {
                    return date
                }
            }
        }
        return nil
    }

    /// Name date → content creation (EXIF/Spotlight) → file creation → modification → now.
    public static func resolve(_ item: FileItem, calendar: Calendar = .current) -> Date {
        dateFromName(item.name, calendar: calendar)
            ?? item.spotlightContentCreationDate
            ?? item.createdAt
            ?? item.modifiedAt
            ?? Date()
    }

    public static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func validDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1990...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day,
              calendar.component(.month, from: date) == month else {
            return nil
        }
        return date
    }
}
