//
//  UnitLocalization.swift
//  Maths
//

import Foundation

/// The locale the library prefers when displaying units.
///
/// Unit names use British English (`en-GB`) by default, so the library shows
/// "metre" and "litre" rather than "meter" and "liter". Callers that need
/// different number formatting can pass their own ``Locale`` to the
/// `formatted` methods.
public enum MathsLocale {
    /// British English, the preferred locale for unit display.
    public static let preferred = Locale(identifier: "en_GB")
}

/// Resolves localized unit names and display symbols from the package catalog.
///
/// Catalog entries use two stable key patterns:
///
/// * `unit.name.<key>` — the human-readable unit name, e.g. `"metre"`.
/// * `unit.symbol.<key>` — the symbol shown when formatting, e.g. `"m"`.
///
/// `<key>` is the `localizationKey` passed to ``NamedUnit``. The canonical unit
/// symbol remains locale-independent; only the display symbol is localized.
enum UnitLocalization {
    /// The British English localization preferred by the library.
    static let preferredLocalization = "en-GB"

    /// The string table generated into `Resources/Localisable.xcstrings`.
    static let tableName = "Localisable"

    /// Looks up a localized unit name, falling back to a readable form of the
    /// localization key.
    static func name(for key: String, dimension: PhysicalDimension) -> String {
        string(
            for: "unit.name.\(key)",
            fallback: fallbackName(for: key, dimension: dimension)
        )
    }

    /// Looks up a localized unit symbol, falling back to the canonical symbol.
    static func symbol(for key: String, fallback: String) -> String {
        string(for: "unit.symbol.\(key)", fallback: fallback)
    }

    /// The British English fallback name used when the catalog is unavailable.
    ///
    /// For example, `"nauticalMile"` becomes `"nautical mile"`, `"kilometer"`
    /// becomes `"kilometre"`, and a currency key such as `"usd"` becomes
    /// `"USD"`.
    static func fallbackName(for key: String, dimension: PhysicalDimension) -> String {
        if dimension == .currency {
            return key.uppercased()
        }

        let special: [String: String] = [
            "us": "US",
            "uk": "UK",
            "tnt": "TNT",
            "planck": "Planck",
            "british": "British",
            "japanese": "Japanese",
            "celsius": "Celsius",
            "fahrenheit": "Fahrenheit",
            "btc": "BTC",
            "eth": "ETH",
        ]

        let characters = Array(key)
        var spaced = ""
        for (index, character) in characters.enumerated() {
            if index > 0,
               character.isUppercase,
               characters[index - 1].isLowercase || characters[index - 1].isNumber {
                spaced.append(" ")
            }
            spaced.append(character)
        }

        let name = spaced
            .split(separator: " ")
            .map { word in
                let lowercased = word.lowercased()
                return special[lowercased] ?? lowercased
            }
            .joined(separator: " ")

        return britishSpelling(name)
    }

    /// The package resource bundle that contains `Localisable.strings`.
    ///
    /// The British English `.lproj` is selected explicitly so the preferred
    /// spellings are used even when the host app runs in another English
    /// region. If the localization is unavailable, the module bundle's normal
    /// lookup is used.
    static var bundle: Bundle {
        guard let path = Bundle.module.path(
            forResource: preferredLocalization,
            ofType: "lproj"
        ),
        let localized = Bundle(path: path) else {
            return .module
        }
        return localized
    }

    private static func britishSpelling(_ name: String) -> String {
        name
            .replacingOccurrences(of: "meter", with: "metre")
            .replacingOccurrences(of: "Meter", with: "Metre")
            .replacingOccurrences(of: "liter", with: "litre")
            .replacingOccurrences(of: "Liter", with: "Litre")
    }

    private static func string(for key: String, fallback: String) -> String {
        NSLocalizedString(
            key,
            tableName: tableName,
            bundle: bundle,
            value: fallback,
            comment: "Localized unit name or symbol"
        )
    }
}
