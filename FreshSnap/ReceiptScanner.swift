//
//  ReceiptScanner.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 30/10/2026.
//

import Foundation
import UIKit
import Vision
 
// FreshSnap – Week 6, Steps 4 and 5
// Turns a photo of a receipt into fridge items:
// 1. ReceiptReader: Apple's Vision reads every line of text on the photo.
// 2. ReceiptParser: finds lines with a price, expands abbreviations
//    ("SS MLK 2L" -> "Semi-skimmed milk", 2 L) and guesses a category.
 
struct ReceiptItem: Identifiable {
    let id = UUID()
    var include = true
    var name: String
    var amount: String
    var price: Double
    var category: String
    var expiryDate: Date
    var estimateSource: String  // where the use-by date came from
    let receiptText: String     // what was printed, so the user can check it
}
 
// MARK: - 1. Reading the text
 
enum ReceiptReader {
    static func readRows(from image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
 
        // Text recognition is slow, so it runs in the background, not on the main screen.
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false   // receipts are full of abbreviations
            request.recognitionLanguages = ["en-GB"]
 
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try? handler.perform([request])
            return ReceiptReader.rows(from: request.results ?? [])
        }.value
    }
 
    // Vision returns separate pieces of text; a receipt line is usually the item name
    // on the left and the price on the right, so pieces at the same height are joined.
    nonisolated static func rows(from observations: [VNRecognizedTextObservation]) -> [String] {
        let pieces = observations
            .compactMap { observation -> (text: String, midY: CGFloat, minX: CGFloat, height: CGFloat)? in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                let box = observation.boundingBox   // 0–1, measured from the bottom-left
                return (text, box.midY, box.minX, box.height)
            }
            .sorted { $0.midY > $1.midY }           // top of the receipt first
 
        var rows: [[(text: String, midY: CGFloat, minX: CGFloat, height: CGFloat)]] = []
        for piece in pieces {
            if let first = rows.last?.first, abs(first.midY - piece.midY) < first.height * 0.6 {
                rows[rows.count - 1].append(piece)
            } else {
                rows.append([piece])
            }
        }
 
        return rows.map { row in
            row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ")
        }
    }
}
 
extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
 
// MARK: - 2. Understanding the lines
 
enum ReceiptParser {
    // A line ending in a price, optionally followed by a VAT code: "SS MLK 2L 1.15 A"
    private static let pricePattern = try! NSRegularExpression(
        pattern: #"^(.*?)[\s£]*(-?\d{1,3}\.\d{2})\s*[A-Z*]{0,2}\s*$"#
    )
 
    // Sizes: 2L, 400G, 1.5KG, 500ML, 6PK
    private static let sizePattern = try! NSRegularExpression(
        pattern: #"^(\d+(?:\.\d+)?)(G|KG|ML|CL|L|PK|PACK)$"#
    )
 
    // Lines that are about payment or offers, not food
    private static let skipWords = [
        "TOTAL", "SUBTOTAL", "SUB-TOTAL", "BALANCE", "CARD", "CASH", "CHANGE", "VISA",
        "MASTERCARD", "DEBIT", "CREDIT", "CONTACTLESS", "VAT", "SAVING", "SAVINGS",
        "CLUBCARD", "NECTAR", "LOYALTY", "MULTIBUY", "DISCOUNT", "PROMO", "PROMOTION",
        "REDUCED", "BAG", "BAGS", "CARRIER", "POINTS", "REFUND", "AUTH", "TEL", "WWW",
        "THANK", "RECEIPT", "ITEMS", "MERCHANT", "TERMINAL", "PAID", "DUE", "COUPON",
        "VOUCHER", "DEPOSIT", "PRICE", "AMOUNT", "GBP", "SALE", "PURCHASE", "APPROVED"
    ]
 
    // Store names and range names that aren't part of the product name
    private static let storeWords: Set<String> = [
        "TSCO", "TESCO", "SAINSBURYS", "SBURYS", "JS", "ASDA", "ALDI", "LIDL",
        "MORRISONS", "MORR", "COOP", "CO-OP", "M&S", "WAITROSE", "ICELAND", "FINEST", "VALUE"
    ]
 
    // The abbreviation dictionary. Add to it as you scan more receipts.
    private static let abbreviations: [String: String] = [
        // Dairy and eggs
        "SS": "semi-skimmed", "S/S": "semi-skimmed", "SEMI": "semi-skimmed",
        "SKMD": "skimmed", "SKIM": "skimmed", "WHL": "whole", "MLK": "milk",
        "CHS": "cheese", "CHSE": "cheese", "CHED": "cheddar", "CHDR": "cheddar",
        "MAT": "mature", "MATR": "mature", "MOZZ": "mozzarella",
        "YOG": "yoghurt", "YGT": "yoghurt", "YOGT": "yoghurt", "GRK": "Greek",
        "BTR": "butter", "BUTT": "butter", "CRM": "cream", "DBL": "double", "SNGL": "single",
        "RNG": "range", "LGE": "large", "LRG": "large", "MED": "medium",
        // Meat and fish
        "CHKN": "chicken", "CHCKN": "chicken", "CHIC": "chicken", "CKN": "chicken",
        "BRST": "breast", "BRSTS": "breasts", "FLLT": "fillet", "FLLTS": "fillets",
        "THGH": "thighs", "MNCE": "mince", "MINC": "mince", "BF": "beef", "PRK": "pork",
        "SSGS": "sausages", "SAUS": "sausages", "BCN": "bacon", "SMKD": "smoked",
        "UNSMKD": "unsmoked", "HM": "ham", "SALM": "salmon", "FSH": "fish",
        // Bakery
        "BRD": "bread", "WHT": "white", "WHLML": "wholemeal", "WMEAL": "wholemeal",
        "BRN": "brown", "SLCD": "sliced", "THK": "thick", "RLLS": "rolls",
        // Fruit and veg
        "BAN": "bananas", "BANS": "bananas", "BNNA": "bananas", "APPL": "apples",
        "STRAWB": "strawberries", "STRWB": "strawberries", "BLUEB": "blueberries",
        "RASPB": "raspberries", "GRPS": "grapes", "TOM": "tomatoes", "TOMS": "tomatoes",
        "POT": "potatoes", "POTS": "potatoes", "ONN": "onions", "CARR": "carrots",
        "CRRT": "carrots", "CRRTS": "carrots", "SPIN": "spinach", "SPNCH": "spinach",
        "BROC": "broccoli", "LETT": "lettuce", "CUC": "cucumber", "CUCMB": "cucumber",
        "PEPP": "peppers", "PPRS": "peppers", "MUSH": "mushrooms", "MSHRM": "mushrooms",
        "MSHRMS": "mushrooms", "AVO": "avocado", "GRLC": "garlic",
        // Cupboard and other
        "PSTA": "pasta", "RCE": "rice", "OJ": "orange juice", "JCE": "juice",
        "ORNG": "orange", "FRZN": "frozen", "FRZ": "frozen", "VEG": "vegetables",
        "ORG": "organic", "WAF": "wafers", "WAFS": "wafers"
    ]
 
    // Words that suggest a category, checked in this order
    private static let categoryWords: [(category: String, words: [String])] = [
        ("Frozen", ["frozen", "ice cream"]),
        ("Meat and fish", ["chicken", "beef", "mince", "pork", "bacon", "sausage", "ham",
                           "turkey", "lamb", "steak", "fish", "salmon", "tuna", "cod",
                           "prawn", "haddock", "chorizo"]),
        ("Dairy and eggs", ["milk", "cheese", "cheddar", "mozzarella", "yoghurt", "yogurt",
                            "butter", "cream", "egg"]),
        ("Bakery", ["bread", "roll", "bagel", "croissant", "wrap", "muffin", "crumpet",
                    "loaf", "baguette", "naan", "pitta"]),
        ("Fruit and veg", ["apple", "banana", "orange", "grape", "berr", "lemon", "lime",
                           "avocado", "tomato", "potato", "onion", "carrot", "spinach",
                           "lettuce", "salad", "cucumber", "pepper", "mushroom", "broccoli",
                           "courgette", "garlic", "celery", "kale", "fruit", "veg", "melon", "pear"]),
        ("Cupboard", ["pasta", "rice", "noodle", "cereal", "oats", "beans", "soup", "sauce",
                      "crisps", "biscuit", "wafer", "chocolate", "flour", "sugar", "coffee", "tea",
                      "jam", "oil"])
    ]
 
    // Words that mark the end of the item list. Everything after them is
    // the total and payment details, never food.
    private static let endWords = [
        "TOTAL", "SUBTOTAL", "SUB-TOTAL", "BALANCE", "AMOUNT", "TO PAY", "AMOUNT DUE"
    ]
 
    static func items(from rows: [String]) -> [ReceiptItem] {
        var found: [ReceiptItem] = []
        var runningTotal = 0.0
 
        for row in rows {
            let line = row.uppercased()
 
            // 1. Stop at the total line
            if containsAny(endWords, in: line) { break }
 
            guard let item = item(from: row) else { continue }
 
            // 2. Backup check: a price equal to everything above it is the total
            if found.count >= 2 && abs(item.price - runningTotal) < 0.02 { continue }
 
            found.append(item)
            runningTotal += item.price
        }
        return found
    }
 
    private static func item(from row: String) -> ReceiptItem? {
        let line = row.uppercased().trimmingCharacters(in: .whitespaces)
 
        // Skip payment, offer and weighed-item lines
        guard !line.contains("@"), !containsSkipWord(line) else { return nil }
 
        // Must end with a price
        let range = NSRange(line.startIndex..., in: line)
        guard let match = pricePattern.firstMatch(in: line, range: range),
              let nameRange = Range(match.range(at: 1), in: line),
              let priceRange = Range(match.range(at: 2), in: line),
              let price = Double(line[priceRange]), price > 0 else { return nil }
 
        let printedName = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        guard printedName.filter(\.isLetter).count >= 3 else { return nil }
 
        // Expand each word, pulling out the size as the amount
        var words: [String] = []
        var amount = ""
        for token in printedName.split(separator: " ").map(String.init) {
            if storeWords.contains(token) { continue }
            if let size = size(from: token) {
                amount = size
                continue
            }
            // Product codes and other plain numbers, e.g. "0080761"
            if token.allSatisfy(\.isNumber) { continue }
            words.append(abbreviations[token] ?? token.lowercased())
        }
        guard !words.isEmpty else { return nil }
 
        let name = sentenceCase(words.joined(separator: " "))
        let category = guessCategory(for: name)
        let estimate = ShelfLife.estimate(forName: name, category: category)
 
        return ReceiptItem(
            name: name,
            amount: amount,
            price: price,
            category: category,
            expiryDate: estimate.date,
            estimateSource: estimate.source,
            receiptText: row
        )
    }
 
    private static func containsSkipWord(_ line: String) -> Bool {
        containsAny(skipWords, in: line)
    }
 
    // True if any of the words appears as a whole word in the line.
    private static func containsAny(_ words: [String], in line: String) -> Bool {
        words.contains { word in
            line.range(of: "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b",
                       options: .regularExpression) != nil
        }
    }
 
    // "2L" -> "2 L", "400G" -> "400 g", "6PK" -> "6 pack"
    private static func size(from token: String) -> String? {
        let range = NSRange(token.startIndex..., in: token)
        guard let match = sizePattern.firstMatch(in: token, range: range),
              let numberRange = Range(match.range(at: 1), in: token),
              let unitRange = Range(match.range(at: 2), in: token) else { return nil }
 
        let number = token[numberRange]
        switch token[unitRange] {
        case "L": return "\(number) L"
        case "PK", "PACK": return "\(number) pack"
        default: return "\(number) \(token[unitRange].lowercased())"
        }
    }
 
    static func guessCategory(for name: String) -> String {
        let lower = name.lowercased()
        for rule in categoryWords where rule.words.contains(where: { lower.contains($0) }) {
            return rule.category
        }
        return "Other"
    }
 
    private static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
