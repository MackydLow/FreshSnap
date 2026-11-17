//
//  LabelDateReader.swift
//  FreshSnap
//
//  Created by Mack Low on 30/10/2026.
//

import Foundation
 
// FreshSnap – Week 6, Step 3
// Finds the use-by (or best-before) date in the text read from a food label.
// Understands UK date formats: 12/10, 12.10.26, 12-10-2026, 12 OCT, 12th October 2026.
 
struct FoundDate {
    enum Kind {
        case useBy        // about safety
        case bestBefore   // about quality
        case unlabelled   // a date with no wording next to it
    }
 
    let date: Date
    let kind: Kind
}
 
enum LabelDateReader {
    private static let monthNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                     "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
 
    // "12 OCT", "12th October 2026", "12 OCT 26"
    private static let monthNamePattern = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,2})\s*(?:ST|ND|RD|TH)?\s*(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?(?:\s*(\d{4}|\d{2})(?!\d))?"#
    )
 
    // "12/10", "12.10.26", "12-10-2026" (day first, as in the UK).
    // Skips prices like £3.10 and weights like 1.5kg.
    private static let numericPattern = try! NSRegularExpression(
        pattern: #"(?<![£$\d.,])(\d{1,2})[./-](\d{1,2})(?:[./-](\d{4}|\d{2}))?(?![\d.,])(?!\s*(?:KG|G\b|ML|L\b|%|P\b))"#
    )
 
    static func findDate(in lines: [String]) -> FoundDate? {
        let upper = lines.map { $0.uppercased() }
 
        // 1. A date on, or just after, a "use by" line
        if let date = dateNear(keywords: ["USE BY", "USE-BY", "USEBY"], in: upper) {
            return FoundDate(date: date, kind: .useBy)
        }
        // 2. Then a "best before" date
        if let date = dateNear(keywords: ["BEST BEFORE", "BEST-BEFORE", "BBE", "BB"], in: upper) {
            return FoundDate(date: date, kind: .bestBefore)
        }
        // 3. Then any other date, ignoring display-until and packed-on dates
        for line in upper where !line.contains("DISPLAY") && !line.contains("PACKED") {
            if let date = firstDate(in: line) {
                return FoundDate(date: date, kind: .unlabelled)
            }
        }
        return nil
    }
 
    // Looks at the keyword's line plus the next line, as dates often sit underneath.
    private static func dateNear(keywords: [String], in lines: [String]) -> Date? {
        for (index, line) in lines.enumerated() where containsWord(keywords, in: line) {
            let text = index + 1 < lines.count ? line + " " + lines[index + 1] : line
            if let date = firstDate(in: text) {
                return date
            }
        }
        return nil
    }
 
    private static func containsWord(_ keywords: [String], in line: String) -> Bool {
        keywords.contains { keyword in
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: keyword) + "\\b"
            return line.range(of: pattern, options: .regularExpression) != nil
        }
    }
 
    // The earliest date written in the text, in either format.
    private static func firstDate(in text: String) -> Date? {
        let range = NSRange(text.startIndex..., in: text)
        var candidates: [(position: Int, date: Date)] = []
 
        for match in monthNamePattern.matches(in: text, range: range) {
            guard let day = Int(group(1, of: match, in: text) ?? ""),
                  let name = group(2, of: match, in: text),
                  let monthIndex = monthNames.firstIndex(of: name) else { continue }
            let year = Int(group(3, of: match, in: text) ?? "")
            if let date = makeDate(day: day, month: monthIndex + 1, year: year) {
                candidates.append((match.range.location, date))
            }
        }
 
        for match in numericPattern.matches(in: text, range: range) {
            guard let day = Int(group(1, of: match, in: text) ?? ""),
                  let month = Int(group(2, of: match, in: text) ?? "") else { continue }
            let year = Int(group(3, of: match, in: text) ?? "")
            if let date = makeDate(day: day, month: month, year: year) {
                candidates.append((match.range.location, date))
            }
        }
 
        return candidates.min { $0.position < $1.position }?.date
    }
 
    private static func group(_ index: Int, of match: NSTextCheckingResult, in text: String) -> String? {
        let nsRange = match.range(at: index)
        guard nsRange.location != NSNotFound, let range = Range(nsRange, in: text) else { return nil }
        return String(text[range])
    }
 
    private static func makeDate(day: Int, month: Int, year: Int?) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }
 
        let calendar = Calendar.current
        let now = Date.now
        var fullYear = year ?? calendar.component(.year, from: now)
        if fullYear < 100 { fullYear += 2000 }    // "26" -> 2026
 
        var parts = DateComponents(year: fullYear, month: month, day: day)
        // Rejects impossible dates like 31 February
        guard var date = calendar.date(from: parts),
              calendar.component(.day, from: date) == day else { return nil }
 
        // No year printed and the date is long past: it must mean next year.
        if year == nil,
           let cutoff = calendar.date(byAdding: .day, value: -60, to: now),
           date < cutoff {
            parts.year = fullYear + 1
            date = calendar.date(from: parts) ?? date
        }
        return date
    }
}
