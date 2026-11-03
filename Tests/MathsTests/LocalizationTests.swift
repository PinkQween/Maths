import Foundation
import Testing
@testable import Maths

@Suite struct LocalizationTests {
    @Test func localizedNamesAndDisplaySymbols() {
        // The canonical symbol stays in English and is what identity uses.
        #expect(Units.meter.symbol == "m")
        #expect(Units.meter.displaySymbol == "m")

        // The library prefers British English, so both spellings of the API
        // display the UK name.
        #expect(Units.meter.name == "metre")
        #expect(Units.metre.name == "metre")
        #expect(Units.kilometer.name == "kilometre")
        #expect(Units.liter.name == "litre")
        #expect(Units.milliliter.name == "millilitre")
        #expect(Units.metersPerSecond.name == "metres per second")
        #expect(Units.nauticalMile.name == "nautical mile")
        #expect(Units.nauticalMile.displaySymbol == "NM")

        // Proper nouns and currencies are formatted by the generator.
        #expect(Units.celsius.name == "Celsius")
        #expect(Units.celsius.displaySymbol == "°C")
        #expect(Units.usd.name == "USD")
        #expect(Units.usd.displaySymbol == "$")
        #expect(Units.decibelSoundPressureLevel.name == "decibel sound pressure level")

        // Built-in counting scales participate in the same catalog.
        #expect(Units.dozen.name == "dozen")
        #expect(Units.dozen.displaySymbol == "doz")
        #expect(Units.halfDozen.name == "half dozen")
    }

    @Test func prefersBritishEnglish() {
        #expect(MathsLocale.preferred.identifier == "en_GB")
        #expect(UnitLocalization.preferredLocalization == "en-GB")
    }

    @Test func catalogIsBundled() {
        // If the catalog were missing, localizedString would return the fallback.
        let value = UnitLocalization.bundle.localizedString(
            forKey: "unit.name.meter",
            value: "MISSING",
            table: UnitLocalization.tableName
        )
        #expect(value == "metre")
    }

    @Test func catalogContainsFrenchGermanRussian() {
        func localized(_ language: String, key: String) -> String {
            let path = Bundle.module.path(forResource: language, ofType: "lproj")!
            let bundle = Bundle(path: path)!
            return bundle.localizedString(
                forKey: key,
                value: "MISSING",
                table: UnitLocalization.tableName
            )
        }

        #expect(localized("fr", key: "unit.name.meter") == "mètre")
        #expect(localized("de", key: "unit.name.meter") == "Meter")
        #expect(localized("ru", key: "unit.name.meter") == "метр")

        // Prefixed names are composed from the same base + prefix tables.
        #expect(localized("fr", key: "unit.name.kilometer") == "kilomètre")
        #expect(localized("de", key: "unit.name.kilometer") == "Kilometer")
        #expect(localized("ru", key: "unit.name.kilometer") == "километр")

        // Multi-word and currency entries are fully localized.
        #expect(localized("fr", key: "unit.name.nauticalMile") == "mille marin")
        #expect(localized("de", key: "unit.name.nauticalMile") == "Seemeile")
        #expect(localized("ru", key: "unit.name.nauticalMile") == "морская миля")
        #expect(localized("fr", key: "unit.name.usd") == "dollar américain")
        #expect(localized("ru", key: "unit.name.eur") == "евро")

        // Every language keeps the canonical symbol.
        #expect(localized("fr", key: "unit.symbol.meter") == "m")
        #expect(localized("ru", key: "unit.symbol.nauticalMile") == "NM")
    }

    @Test func formattingUsesDisplaySymbol() {
        let formatted = QuantityFormatting.format(
            value: 5,
            unit: Units.metre,
            decimalPlaces: 2,
            includeSpace: true,
            locale: Locale(identifier: "en_US_POSIX")
        )
        #expect(formatted == "5.00 m")
    }

    @Test func encodingAndDecodingPreservesLocalization() throws {
        let data = try JSONEncoder().encode(Units.metre)
        let decoded = try JSONDecoder().decode(
            NamedUnit<MathDimension.length>.self,
            from: data
        )

        #expect(decoded.symbol == "m")
        #expect(decoded.name == "metre")
        #expect(decoded.displaySymbol == "m")
    }

    @Test func erasedUnitPreservesLocalizedValues() {
        let erased = AnyMathUnit(Units.nauticalMile)
        #expect(erased.symbol == "NM")
        #expect(erased.name == "nautical mile")
        #expect(erased.displaySymbol == "NM")
    }

    @Test func ratioUsesLocalizedOperandSymbols() {
        let ratio = Units.usd.per(Units.kilogram)
        #expect(ratio.symbol == "($/kg)")
        #expect(ratio.displaySymbol == "($/kg)")
    }

    @Test func missingCatalogEntryFallsBackToReadableText() {
        let custom = NamedUnit<MathDimension.length>(
            symbol: "smoot",
            dimension: .length,
            converter: LinearConverter(coefficient: 1.7),
            localizationKey: "smoot"
        )

        #expect(custom.name == "smoot")
        #expect(custom.displaySymbol == "smoot")
    }
}
