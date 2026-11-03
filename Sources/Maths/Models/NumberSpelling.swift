//
//  NumberSpelling.swift
//  Maths
//
//  Created by Hanna Skairipa on 02/11/26.
//

import Foundation

/// How individual digits are spoken when spelling out a number.
///
/// ``NumberSpellingStyle/standard`` spells numbers normally (`nine`, `five`).
/// ``NumberSpellingStyle/aviation`` uses the ICAO/NATO radio pronunciation for
/// the digit words (`niner`, `fife`). Aviation pronunciation applies to the
/// single digit words in English; other languages keep their ordinary words.
public enum NumberSpellingStyle: Sendable, Hashable {
    case standard
    case aviation
}

/// Spells numbers out as words.
///
/// `NumberSpeller` converts a `Decimal` (or an arbitrary-length digit string)
/// into written words, localised to English (US), English (UK — the default),
/// French, German, and Russian:
///
/// ```swift
/// NumberSpeller.spelledOut(Decimal(string: "23")!)                       // "twenty-three"
/// NumberSpeller.spelledOut(Decimal(string: "0.45")!)                     // "forty-five hundredths"
/// NumberSpeller.spelledOut(Decimal(string: "9")!, style: .aviation)      // "niner"
/// NumberSpeller.spelledOut(Decimal(string: "45")!, locale: Locale(identifier: "ru_RU"))
/// // "сорок пять"
/// ```
///
/// Whole numbers use the short scale for English and Russian and the long
/// scale for French and German. Fractions are written as denominators
/// ("forty-five hundredths") up to eighteen decimal places, after which the
/// digits are read one at a time ("point four five ...").
public enum NumberSpeller {
    /// Spells a decimal value as words.
    ///
    /// - Parameters:
    ///   - value: The decimal to spell. Its integer part is spelled out in
    ///     full; a fractional part is written as a fraction where possible.
    ///   - locale: The locale to spell in. Defaults to
    ///     ``MathsLocale/preferred`` (British English). Unsupported locales
    ///     fall back to British English.
    ///   - style: ``NumberSpellingStyle/standard`` or
    ///     ``NumberSpellingStyle/aviation``.
    public static func spelledOut(
        _ value: Decimal,
        locale: Locale = MathsLocale.preferred,
        style: NumberSpellingStyle = .standard
    ) -> String {
        spelledOut(String(describing: value), locale: locale, style: style)
    }

    /// Spells a decimal string as words, supporting arbitrarily large integers.
    ///
    /// The string must match `-?[0-9]+(\.[0-9]+)?`.
    public static func spelledOut(
        _ decimalString: String,
        locale: Locale = MathsLocale.preferred,
        style: NumberSpellingStyle = .standard
    ) -> String {
        let language = SpellingLanguage(locale: locale) ?? .englishGB
        let engine = SpellingEngine(language: language, style: style)
        return engine.spell(decimalString)
    }
}

// MARK: - Engine

private enum SpellingLanguage: Sendable {
    case englishUS, englishGB, french, german, russian

    init?(locale: Locale) {
        let language = locale.languageCode ?? ""
        let region = (locale.regionCode ?? "").uppercased()
        switch language {
        case "en": self = region == "GB" ? .englishGB : .englishUS
        case "fr": self = .french
        case "de": self = .german
        case "ru": self = .russian
        default: return nil
        }
    }
}

private struct SpellingEngine {
    let language: SpellingLanguage
    let style: NumberSpellingStyle

    func spell(_ decimalString: String) -> String {
        let parsed = ParsedDecimal(decimalString)
        let integer = spellInteger(parsed.integerDigits)
        guard let fraction = parsed.fractionDigits, !fraction.isEmpty else {
            return sign(parsed.negative) + integer
        }

        let fractionWords = spellFraction(fraction)
        let connector = fractionConnector
        let joined = integer == zeroWord
            ? fractionWords
            : integer + connector + fractionWords
        return sign(parsed.negative) + joined
    }
}

private struct ParsedDecimal {
    let negative: Bool
    let integerDigits: String
    let fractionDigits: String?

    init(_ raw: String) {
        var string = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        negative = string.first == "-"
        if string.first == "-" || string.first == "+" {
            string.removeFirst()
        }

        let parts = string.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        var integer = String(parts[0]).filter(\.isNumber)
        integer = String(integer.drop { $0 == "0" })
        if integer.isEmpty { integer = "0" }

        var fraction: String? = nil
        if parts.count > 1 {
            let rawFraction = String(parts[1]).filter(\.isNumber)
            var trimmed = rawFraction
            while trimmed.hasSuffix("0") && trimmed.count > 1 {
                trimmed.removeLast()
            }
            if trimmed != "0" {
                fraction = trimmed
            }
        }

        self.integerDigits = integer
        self.fractionDigits = fraction
    }
}

// MARK: - Integer spelling

private extension SpellingEngine {
    var zeroWord: String {
        switch language {
        case .englishUS, .englishGB: return "zero"
        case .french: return "zéro"
        case .german: return "null"
        case .russian: return "ноль"
        }
    }

    var minusWord: String {
        switch language {
        case .englishUS, .englishGB: return "minus "
        case .french: return "moins "
        case .german: return "minus "
        case .russian: return "минус "
        }
    }

    func sign(_ negative: Bool) -> String {
        negative ? minusWord : ""
    }

    func spellInteger(_ digits: String) -> String {
        if digits == "0" { return zeroWord }

        let groups = groups(of: digits)
        var parts: [(index: Int, value: Int, words: String)] = []
        for index in 0..<groups.count {
            let value = groups[index]
            guard value != 0 else { continue }
            let feminine = language == .russian && (scaleForms(index: index)?.russianFeminine ?? false)
            var words = groupWords(value, russianFeminine: feminine)
            if index > 0, let scale = scaleWord(index: index, value: value) {
                words = joinGroupAndScale(words, scale, index: index, value: value)
            }
            parts.append((index, value, words))
        }

        // parts are built low→high; render high→low.
        return joinGroups(parts.sorted { $0.index > $1.index })
    }

    func groups(of digits: String) -> [Int] {
        var result: [Int] = []
        var string = digits
        while !string.isEmpty {
            let length = min(3, string.count)
            let start = string.index(string.endIndex, offsetBy: -length)
            let chunk = String(string[start...])
            string.removeSubrange(start...)
            result.append(Int(chunk) ?? 0)
        }
        return result
    }

    func groupWords(_ value: Int, russianFeminine: Bool) -> String {
        switch language {
        case .englishUS, .englishGB:
            return englishUnderThousand(value, useAnd: language == .englishGB, style: style)
        case .french:
            return frenchUnderThousand(value)
        case .german:
            return germanUnderThousand(value)
        case .russian:
            return russianUnderThousand(value, feminine: russianFeminine)
        }
    }

    func joinGroupAndScale(
        _ words: String,
        _ scale: String,
        index: Int,
        value: Int
    ) -> String {
        switch language {
        case .englishUS, .englishGB:
            return words + " " + scale
        case .french:
            if index == 1 && value == 1 { return "mille" }
            return words + " " + scale
        case .german:
            if index == 1 {
                return value == 1 ? "tausend" : words + "tausend"
            }
            if value == 1 { return "eine " + scale }
            return words + " " + scale
        case .russian:
            return words + " " + scale
        }
    }

    func joinGroups(_ parts: [(index: Int, value: Int, words: String)]) -> String {
        var result = ""
        for (offset, part) in parts.enumerated() {
            if offset > 0 {
                result += groupSeparator(beforeLast: offset == parts.count - 1, lastValue: parts.last?.value ?? 0)
            }
            result += part.words
        }
        return result
    }

    func groupSeparator(beforeLast: Bool, lastValue: Int) -> String {
        switch language {
        case .englishUS:
            return ", "
        case .englishGB:
            if beforeLast && lastValue < 100 { return " and " }
            return ", "
        case .french, .german, .russian:
            return " "
        }
    }
}

// MARK: - Scale words

private struct ScaleForms {
    let singular: String
    let plural: String
    // Russian agreement: singular, genitive singular, genitive plural.
    let genitiveSingular: String?
    let genitivePlural: String?
    let russianFeminine: Bool

    init(
        singular: String,
        plural: String,
        genitiveSingular: String? = nil,
        genitivePlural: String? = nil,
        russianFeminine: Bool = false
    ) {
        self.singular = singular
        self.plural = plural
        self.genitiveSingular = genitiveSingular
        self.genitivePlural = genitivePlural
        self.russianFeminine = russianFeminine
    }
}

private extension SpellingEngine {
    /// The scale name for a non-zero group at `index` (1 = thousand, 2 = million, ...).
    func scaleWord(index: Int, value: Int) -> String? {
        guard let forms = scaleForms(index: index) else { return nil }
        switch language {
        case .englishUS, .englishGB:
            // English scale names are invariant after a number ("twenty-three million").
            return forms.singular
        case .french, .german:
            return value == 1 ? forms.singular : forms.plural
        case .russian:
            return russianScaleForm(forms, value: value)
        }
    }

    private func russianScaleForm(_ forms: ScaleForms, value: Int) -> String {
        let lastTwo = value % 100
        if lastTwo >= 11 && lastTwo <= 14 { return forms.genitivePlural ?? forms.plural }
        switch value % 10 {
        case 1: return forms.singular
        case 2, 3, 4: return forms.genitiveSingular ?? forms.plural
        default: return forms.genitivePlural ?? forms.plural
        }
    }

    private func scaleForms(index: Int) -> ScaleForms? {
        switch language {
        case .englishUS, .englishGB:
            return englishScale(index)
        case .french:
            return frenchScale(index)
        case .german:
            return germanScale(index)
        case .russian:
            return russianScale(index)
        }
    }
}

private func englishScale(_ index: Int) -> ScaleForms? {
    let singular: String
    switch index {
    case 1: singular = "thousand"
    case 2: singular = "million"
    case 3: singular = "billion"
    case 4: singular = "trillion"
    case 5: singular = "quadrillion"
    case 6: singular = "quintillion"
    case 7: singular = "sextillion"
    case 8: singular = "septillion"
    case 9: singular = "octillion"
    case 10: singular = "nonillion"
    case 11: singular = "decillion"
    case 12: singular = "undecillion"
    case 13: singular = "duodecillion"
    case 14: singular = "tredecillion"
    case 15: singular = "quattuordecillion"
    case 16: singular = "quindecillion"
    case 17: singular = "sexdecillion"
    case 18: singular = "septendecillion"
    case 19: singular = "octodecillion"
    case 20: singular = "novemdecillion"
    case 21: singular = "vigintillion"
    case 100: singular = "centillion"
    default:
        guard index > 21, index < 100 else { return nil }
        singular = englishComposedScale(index)
    }
    return ScaleForms(singular: singular, plural: singular + "s")
}

private func englishComposedScale(_ index: Int) -> String {
    // Best-effort Conway–Guy naming for 22...99.
    let unitRoots = [
        "", "un", "duo", "tre", "quattuor", "quin", "sex", "septen", "octo", "novem"
    ]
    let tensRoots = [
        "", "", "viginti", "triginta", "quadraginta", "quinquaginta",
        "sexaginta", "septuaginta", "octoginta", "nonaginta"
    ]
    let tens = index / 10
    let units = index % 10
    let root: String
    if units == 0 {
        root = tensRoots[tens]
    } else {
        root = tensRoots[tens] + connector(units) + unitRoots[units]
    }
    return root + "illion"
}

private func connector(_ unit: Int) -> String {
    switch unit {
    case 3, 4, 5: return "s"
    case 6, 7: return "n"
    case 8, 9: return "x"
    default: return ""
    }
}

private func frenchScale(_ index: Int) -> ScaleForms? {
    let names: [Int: (String, String)] = [
        1: ("mille", "mille"),
        2: ("million", "millions"),
        3: ("milliard", "milliards"),
        4: ("billion", "billions"),
        5: ("billiard", "billiards"),
        6: ("trillion", "trillions"),
        7: ("trilliard", "trilliards"),
        8: ("quadrillion", "quadrillions"),
        9: ("quadrilliard", "quadrilliards"),
        10: ("quintillion", "quintillions"),
        11: ("quintilliard", "quintilliards"),
        12: ("sextillion", "sextillions"),
        13: ("sextilliard", "sextilliards"),
        14: ("septillion", "septillions"),
        15: ("septilliard", "septilliards"),
        16: ("octillion", "octillions"),
        17: ("octilliard", "octilliards"),
        18: ("nonillion", "nonillions"),
        19: ("nonilliard", "nonilliards"),
        20: ("décillion", "décillions"),
        21: ("décilliard", "décilliards"),
    ]
    guard let name = names[index] else { return nil }
    return ScaleForms(singular: name.0, plural: name.1)
}

private func germanScale(_ index: Int) -> ScaleForms? {
    let names: [Int: (String, String)] = [
        1: ("tausend", "tausend"),
        2: ("Million", "Millionen"),
        3: ("Milliarde", "Milliarden"),
        4: ("Billion", "Billionen"),
        5: ("Billiarde", "Billiarden"),
        6: ("Trillion", "Trillionen"),
        7: ("Trilliarde", "Trilliarden"),
        8: ("Quadrillion", "Quadrillionen"),
        9: ("Quadrilliarde", "Quadrilliarden"),
        10: ("Quintillion", "Quintillionen"),
        11: ("Quintilliarde", "Quintilliarden"),
        12: ("Sextillion", "Sextillionen"),
        13: ("Sextilliarde", "Sextilliarden"),
        14: ("Septillion", "Septillionen"),
        15: ("Septilliarde", "Septilliarden"),
        16: ("Oktillion", "Oktillionen"),
        17: ("Oktilliarde", "Oktilliarden"),
        18: ("Nonillion", "Nonillionen"),
        19: ("Nonilliarde", "Nonilliarden"),
        20: ("Dezillion", "Dezillionen"),
        21: ("Dezilliarde", "Dezilliarden"),
    ]
    guard let name = names[index] else { return nil }
    return ScaleForms(singular: name.0, plural: name.1)
}

private func russianScale(_ index: Int) -> ScaleForms? {
    let names: [Int: (String, String, String, Bool)] = [
        1: ("тысяча", "тысячи", "тысяч", true),
        2: ("миллион", "миллиона", "миллионов", false),
        3: ("миллиард", "миллиарда", "миллиардов", false),
        4: ("триллион", "триллиона", "триллионов", false),
        5: ("квадриллион", "квадриллиона", "квадриллионов", false),
        6: ("квинтиллион", "квинтиллиона", "квинтиллионов", false),
        7: ("секстиллион", "секстиллиона", "секстиллионов", false),
        8: ("септиллион", "септиллиона", "септиллионов", false),
        9: ("октиллион", "октиллиона", "октиллионов", false),
        10: ("нониллион", "нониллиона", "нониллионов", false),
        11: ("дециллион", "дециллиона", "дециллионов", false),
        12: ("ундециллион", "ундециллиона", "ундециллионов", false),
        13: ("додециллион", "додециллиона", "додециллионов", false),
        14: ("тредециллион", "тредециллиона", "тредециллионов", false),
        15: ("кваттуордециллион", "кваттуордециллиона", "кваттуордециллионов", false),
        16: ("квиндециллион", "квиндециллиона", "квиндециллионов", false),
        17: ("сексдециллион", "сексдециллиона", "сексдециллионов", false),
        18: ("септдециллион", "септдециллиона", "септдециллионов", false),
        19: ("октодециллион", "октодециллиона", "октодециллионов", false),
        20: ("новемдециллион", "новемдециллиона", "новемдециллионов", false),
        21: ("вигинтиллион", "вигинтиллиона", "вигинтиллионов", false),
    ]
    guard let name = names[index] else { return nil }
    return ScaleForms(
        singular: name.0,
        plural: name.2,
        genitiveSingular: name.1,
        genitivePlural: name.2,
        russianFeminine: name.3
    )
}

// MARK: - English small numbers

private func englishUnits(_ style: NumberSpellingStyle) -> [String] {
    switch style {
    case .standard:
        return ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
    case .aviation:
        return ["zero", "one", "two", "tree", "fower", "fife", "six", "seven", "eight", "niner"]
    }
}

private func englishUnderThousand(_ value: Int, useAnd: Bool, style: NumberSpellingStyle) -> String {
    let units = englishUnits(style)
    let teens = ["ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
    let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

    func under100(_ n: Int) -> String {
        if n < 10 { return units[n] }
        if n < 20 { return teens[n - 10] }
        let t = n / 10, u = n % 10
        return u == 0 ? tens[t] : tens[t] + "-" + units[u]
    }

    let hundreds = value / 100
    let remainder = value % 100
    var parts: [String] = []
    if hundreds > 0 {
        parts.append(units[hundreds] + " hundred")
    }
    if remainder > 0 {
        let rest = under100(remainder)
        if hundreds > 0 && useAnd {
            parts.append("and " + rest)
        } else {
            parts.append(rest)
        }
    }
    return parts.joined(separator: " ")
}

// MARK: - French small numbers

private let frenchUnits = ["zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf"]
private let frenchTeens = ["dix", "onze", "douze", "treize", "quatorze", "quinze", "seize", "dix-sept", "dix-huit", "dix-neuf"]

private func frenchUnder100(_ n: Int) -> String {
    if n < 17 {
        return n < 10 ? frenchUnits[n] : frenchTeens[n - 10]
    }
    if n < 20 {
        return frenchTeens[n - 10]
    }
    if n < 70 {
        let t = n / 10
        let u = n % 10
        let tens = ["", "", "vingt", "trente", "quarante", "cinquante", "soixante"][t]
        if u == 0 { return tens }
        if u == 1 { return tens + " et un" }
        return tens + "-" + frenchUnits[u]
    }
    if n < 80 {
        // soixante-dix ... soixante-dix-neuf
        let u = n - 60
        if u == 11 { return "soixante et onze" }
        return "soixante-" + frenchTeens[u - 10]
    }
    if n < 90 {
        // quatre-vingt ... quatre-vingt-dix-neuf
        let u = n - 80
        if u == 0 { return "quatre-vingts" }
        return "quatre-vingt-" + frenchUnits[u]
    }
    // 90...99
    let u = n - 80
    return "quatre-vingt-" + frenchTeens[u - 10]
}

private func frenchUnderThousand(_ value: Int) -> String {
    let hundreds = value / 100
    let remainder = value % 100

    var prefix: String
    if hundreds == 0 {
        prefix = ""
    } else if hundreds == 1 {
        prefix = "cent"
    } else if remainder == 0 {
        prefix = frenchUnits[hundreds] + " cents"
    } else {
        prefix = frenchUnits[hundreds] + " cent"
    }

    if remainder == 0 {
        return prefix
    }
    return prefix.isEmpty ? frenchUnder100(remainder) : prefix + " " + frenchUnder100(remainder)
}

// MARK: - German small numbers

private let germanUnits = ["null", "ein", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun"]
private let germanTeens = ["zehn", "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn"]
private let germanTens = ["", "", "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig"]

private func germanUnder100(_ n: Int) -> String {
    if n == 0 { return "null" }
    if n == 1 { return "eins" }
    if n < 10 { return germanUnits[n] }
    if n < 20 { return germanTeens[n - 10] }
    let t = n / 10
    let u = n % 10
    if u == 0 { return germanTens[t] }
    let unit = (u == 1 ? "ein" : germanUnits[u])
    return unit + "und" + germanTens[t]
}

private func germanUnderThousand(_ value: Int) -> String {
    if value == 0 { return "null" }
    let hundreds = value / 100
    let remainder = value % 100
    var result = ""
    if hundreds > 0 {
        result += (hundreds == 1 ? "ein" : germanUnits[hundreds]) + "hundert"
    }
    if remainder > 0 {
        result += germanUnder100(remainder)
    }
    return result
}

// MARK: - Russian small numbers

private let russianUnits = ["ноль", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"]
private let russianTeens = ["десять", "одиннадцать", "двенадцать", "тринадцать", "четырнадцать", "пятнадцать", "шестнадцать", "семнадцать", "восемнадцать", "девятнадцать"]
private let russianTens = ["", "", "двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "семьдесят", "восемьдесят", "девяносто"]
private let russianHundreds = ["", "сто", "двести", "триста", "четыреста", "пятьсот", "шестьсот", "семьсот", "восемьсот", "девятьсот"]

private func russianUnderThousand(_ value: Int, feminine: Bool) -> String {
    if value == 0 { return "ноль" }

    let hundreds = value / 100
    let remainder = value % 100

    var parts: [String] = []
    if hundreds > 0 {
        parts.append(russianHundreds[hundreds])
    }
    if remainder > 0 {
        if remainder < 10 {
            parts.append(russianUnit(remainder, feminine: feminine))
        } else if remainder < 20 {
            parts.append(russianTeens[remainder - 10])
        } else {
            let t = remainder / 10
            let u = remainder % 10
            if u == 0 {
                parts.append(russianTens[t])
            } else {
                parts.append(russianTens[t] + " " + russianUnit(u, feminine: feminine))
            }
        }
    }
    return parts.joined(separator: " ")
}

private func russianUnit(_ digit: Int, feminine: Bool) -> String {
    if feminine && digit == 1 { return "одна" }
    if feminine && digit == 2 { return "две" }
    return russianUnits[digit]
}

// MARK: - Fractions

private extension SpellingEngine {
    var fractionConnector: String {
        switch language {
        case .englishUS, .englishGB: return " and "
        case .french: return " et "
        case .german: return " und "
        case .russian: return " и "
        }
    }

    var pointWord: String {
        switch language {
        case .englishUS, .englishGB: return "point"
        case .french: return "virgule"
        case .german: return "Komma"
        case .russian: return "запятая"
        }
    }

    func spellFraction(_ digits: String) -> String {
        if digits.count <= 18, let denominator = denominatorWord(places: digits.count) {
            let numerator = Int(digits) ?? 0
            return fractionWords(numerator: numerator, denominator: denominator, places: digits.count)
        }
        return pointDigits(digits)
    }

    func pointDigits(_ digits: String) -> String {
        let words = digits.map { String($0) }.compactMap { digitWord(Int(String($0)) ?? 0) }
        return ([pointWord] + words).joined(separator: " ")
    }

    func digitWord(_ digit: Int) -> String? {
        switch language {
        case .englishUS, .englishGB:
            return englishUnits(style)[digit]
        case .french:
            return frenchUnits[digit]
        case .german:
            return germanUnits[digit]
        case .russian:
            return russianUnits[digit]
        }
    }

    func fractionWords(numerator: Int, denominator: String, places: Int) -> String {
        switch language {
        case .englishUS, .englishGB:
            let numeratorWords = englishUnderThousand(numerator, useAnd: language == .englishGB, style: style)
            let denom = numerator == 1 ? String(denominator.dropLast()) : denominator
            return numeratorWords + " " + denom
        case .french:
            let numeratorWords = frenchUnderThousand(numerator)
            let denom = numerator == 1 ? String(denominator.dropLast()) : denominator
            return numeratorWords + " " + denom
        case .german:
            let numeratorWords = germanUnderThousand(numerator)
            return numeratorWords + " " + denominator
        case .russian:
            let numeratorWords = russianUnderThousand(numerator, feminine: true)
            let denom = numerator == 1 ? (russianDenominatorSingular(places) ?? denominator) : denominator
            return numeratorWords + " " + denom
        }
    }

    func denominatorWord(places: Int) -> String? {
        switch language {
        case .englishUS, .englishGB:
            guard let base = englishDenominator(places) else { return nil }
            return base + "s"
        case .french:
            guard let base = frenchDenominator(places) else { return nil }
            return base + "s"
        case .german:
            return germanDenominator(places)
        case .russian:
            return russianDenominatorPlural(places)
        }
    }
}

private func englishDenominator(_ places: Int) -> String? {
    switch places {
    case 1: return "tenth"
    case 2: return "hundredth"
    case 3: return "thousandth"
    case 4: return "ten-thousandth"
    case 5: return "hundred-thousandth"
    case 6: return "millionth"
    case 7: return "ten-millionth"
    case 8: return "hundred-millionth"
    case 9: return "billionth"
    case 10: return "ten-billionth"
    case 11: return "hundred-billionth"
    case 12: return "trillionth"
    case 13: return "ten-trillionth"
    case 14: return "hundred-trillionth"
    case 15: return "quadrillionth"
    case 16: return "ten-quadrillionth"
    case 17: return "hundred-quadrillionth"
    case 18: return "quintillionth"
    default: return nil
    }
}

private func frenchDenominator(_ places: Int) -> String? {
    switch places {
    case 1: return "dixième"
    case 2: return "centième"
    case 3: return "millième"
    case 4: return "dix-millième"
    case 5: return "cent-millième"
    case 6: return "millionième"
    case 7: return "dix-millionième"
    case 8: return "cent-millionième"
    case 9: return "milliardième"
    case 10: return "dix-milliardième"
    case 11: return "cent-milliardième"
    case 12: return "billionième"
    case 13: return "dix-billionième"
    case 14: return "cent-billionième"
    case 15: return "billiardième"
    case 16: return "dix-billiardième"
    case 17: return "cent-billiardième"
    case 18: return "trillionième"
    default: return nil
    }
}

private func germanDenominator(_ places: Int) -> String? {
    switch places {
    case 1: return "Zehntel"
    case 2: return "Hundertstel"
    case 3: return "Tausendstel"
    case 4: return "Zehntausendstel"
    case 5: return "Hunderttausendstel"
    case 6: return "Millionstel"
    case 7: return "Zehnmillionstel"
    case 8: return "Hundertmillionstel"
    case 9: return "Milliardstel"
    case 10: return "Zehnmilliardstel"
    case 11: return "Hundertmilliardstel"
    case 12: return "Billionstel"
    case 13: return "Zehnbillionstel"
    case 14: return "Hundertbillionstel"
    case 15: return "Billiardstel"
    case 16: return "Zehnbilliardstel"
    case 17: return "Hundertbilliardstel"
    case 18: return "Trillionstel"
    default: return nil
    }
}

private func russianDenominatorPlural(_ places: Int) -> String? {
    switch places {
    case 1: return "десятых"
    case 2: return "сотых"
    case 3: return "тысячных"
    case 4: return "десятитысячных"
    case 5: return "стотысячных"
    case 6: return "миллионных"
    case 7: return "десятимиллионных"
    case 8: return "стомиллионных"
    case 9: return "миллиардных"
    default: return nil
    }
}

private func russianDenominatorSingular(_ places: Int) -> String? {
    switch places {
    case 1: return "десятая"
    case 2: return "сотая"
    case 3: return "тысячная"
    case 4: return "десятитысячная"
    case 5: return "стотысячная"
    case 6: return "миллионная"
    case 7: return "десятимиллионная"
    case 8: return "стомиллионная"
    case 9: return "миллиардная"
    default: return nil
    }
}

// MARK: - Quantity conveniences

public extension Decimal {
    /// Spells this decimal out as words in the requested locale.
    func spelledOut(
        locale: Locale = MathsLocale.preferred,
        style: NumberSpellingStyle = .standard
    ) -> String {
        NumberSpeller.spelledOut(self, locale: locale, style: style)
    }
}

public extension Quantity {
    /// Spells this quantity's value out as words, optionally followed by the
    /// localised unit name.
    ///
    /// The unit name is appended in its (singular) localised form; pluralising
    /// unit names is left to the caller.
    func spelledOut(
        locale: Locale = MathsLocale.preferred,
        style: NumberSpellingStyle = .standard,
        includeUnit: Bool = false
    ) -> String {
        let number = NumberSpeller.spelledOut(value, locale: locale, style: style)
        guard includeUnit else { return number }
        return number + " " + unit.name
    }
}

public extension AnyQuantity {
    /// Spells this quantity's value out as words, optionally followed by the
    /// localised unit name.
    func spelledOut(
        locale: Locale = MathsLocale.preferred,
        style: NumberSpellingStyle = .standard,
        includeUnit: Bool = false
    ) -> String {
        let number = NumberSpeller.spelledOut(value, locale: locale, style: style)
        guard includeUnit else { return number }
        return number + " " + unit.name
    }
}
