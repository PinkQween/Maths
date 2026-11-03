import Foundation
import Testing
@testable import Maths

@Suite struct NumberSpellingTests {
    private func en(_ value: String, style: NumberSpellingStyle = .standard) -> String {
        NumberSpeller.spelledOut(Decimal(string: value)!, locale: Locale(identifier: "en_US"), style: style)
    }
    private func gb(_ value: String) -> String {
        NumberSpeller.spelledOut(Decimal(string: value)!, locale: Locale(identifier: "en_GB"))
    }
    private func fr(_ value: String) -> String {
        NumberSpeller.spelledOut(Decimal(string: value)!, locale: Locale(identifier: "fr_FR"))
    }
    private func de(_ value: String) -> String {
        NumberSpeller.spelledOut(Decimal(string: value)!, locale: Locale(identifier: "de_DE"))
    }
    private func ru(_ value: String) -> String {
        NumberSpeller.spelledOut(Decimal(string: value)!, locale: Locale(identifier: "ru_RU"))
    }

    @Test func hugeNumberAcrossScales() {
        let digits = "023894710556124930482771059482311048572119304857204918374611092"
        let result = NumberSpeller.spelledOut(
            digits,
            locale: Locale(identifier: "en_US"),
            style: .standard
        )
        let expected = "twenty-three novemdecillion, "
            + "eight hundred ninety-four octodecillion, "
            + "seven hundred ten septendecillion, "
            + "five hundred fifty-six sexdecillion, "
            + "one hundred twenty-four quindecillion, "
            + "nine hundred thirty quattuordecillion, "
            + "four hundred eighty-two tredecillion, "
            + "seven hundred seventy-one duodecillion, "
            + "fifty-nine undecillion, "
            + "four hundred eighty-two decillion, "
            + "three hundred eleven nonillion, "
            + "forty-eight octillion, "
            + "five hundred seventy-two septillion, "
            + "one hundred nineteen sextillion, "
            + "three hundred four quintillion, "
            + "eight hundred fifty-seven quadrillion, "
            + "two hundred four trillion, "
            + "nine hundred eighteen billion, "
            + "three hundred seventy-four million, "
            + "six hundred eleven thousand, "
            + "ninety-two"
        #expect(result == expected)
    }

    @Test func negativeAndPointFallback() {
        #expect(en("-45") == "minus forty-five")
        #expect(fr("-12") == "moins douze")
        // More than 18 decimal places falls back to digit-by-digit reading.
        let many = "0.1234567890123456789"
        #expect(en(many) == "point one two three four five six seven eight nine zero one two three four five six seven eight nine")
    }

    @Test func quantitySpelling() {
        let q = Quantity(value: 23, unit: Units.metre)
        #expect(q.spelledOut(locale: Locale(identifier: "en_GB")) == "twenty-three")
        #expect(q.spelledOut(locale: Locale(identifier: "en_GB"), includeUnit: true) == "twenty-three metre")
    }

    @Test func englishBasics() {
        #expect(en("0") == "zero")
        #expect(en("5") == "five")
        #expect(en("19") == "nineteen")
        #expect(en("20") == "twenty")
        #expect(en("23") == "twenty-three")
        #expect(en("100") == "one hundred")
        #expect(en("123") == "one hundred twenty-three")
        #expect(en("611") == "six hundred eleven")
        #expect(en("1000") == "one thousand")
        #expect(en("1005") == "one thousand, five")
        #expect(en("1234") == "one thousand, two hundred thirty-four")
        #expect(en("1000000") == "one million")
    }

    @Test func britishUsesAnd() {
        #expect(gb("123") == "one hundred and twenty-three")
        #expect(gb("611") == "six hundred and eleven")
        #expect(gb("1005") == "one thousand and five")
        #expect(gb("1234") == "one thousand, two hundred and thirty-four")
    }

    @Test func fractions() {
        #expect(en("0.45") == "forty-five hundredths")
        #expect(gb("0.45") == "forty-five hundredths")
        #expect(en("0.5") == "five tenths")
        #expect(en("0.05") == "five hundredths")
        #expect(en("1.25") == "one and twenty-five hundredths")
        #expect(en("0.01") == "one hundredth")
    }

    @Test func aviation() {
        #expect(en("9", style: .aviation) == "niner")
        #expect(en("5", style: .aviation) == "fife")
        #expect(en("3", style: .aviation) == "tree")
        #expect(en("4", style: .aviation) == "fower")
        #expect(en("59", style: .aviation) == "fifty-niner")
    }

    @Test func french() {
        #expect(fr("23") == "vingt-trois")
        #expect(fr("80") == "quatre-vingts")
        #expect(fr("81") == "quatre-vingt-un")
        #expect(fr("71") == "soixante et onze")
        #expect(fr("99") == "quatre-vingt-dix-neuf")
        #expect(fr("200") == "deux cents")
        #expect(fr("201") == "deux cent un")
        #expect(fr("1000") == "mille")
        #expect(fr("1000000") == "un million")
        #expect(fr("0.45") == "quarante-cinq centièmes")
    }

    @Test func german() {
        #expect(de("21") == "einundzwanzig")
        #expect(de("123") == "einhundertdreiundzwanzig")
        #expect(de("1000") == "tausend")
        #expect(de("2000") == "zweitausend")
        #expect(de("1000000") == "eine Million")
        #expect(de("2000000") == "zwei Millionen")
        #expect(de("0.45") == "fünfundvierzig Hundertstel")
    }

    @Test func russian() {
        #expect(ru("45") == "сорок пять")
        #expect(ru("1000") == "одна тысяча")
        #expect(ru("2000") == "две тысячи")
        #expect(ru("5000") == "пять тысяч")
        #expect(ru("1000000") == "один миллион")
        #expect(ru("2000000") == "два миллиона")
        #expect(ru("5000000") == "пять миллионов")
        #expect(ru("0.45") == "сорок пять сотых")
    }
}
