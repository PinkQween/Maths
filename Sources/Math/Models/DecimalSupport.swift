//
//  DecimalSupport.swift
//  Math
//
//  Created by Hanna Skairipa on 11/1/26.
//

import Foundation

/// Internal helpers for the `Decimal`-based value type.
///
/// `Decimal` is not a `FloatingPoint`, so it has no `rounded()`, `infinity`,
/// `log`, or `pow`. These helpers fill those gaps while keeping the exact
/// base-10 arithmetic used everywhere else in the library. Only genuinely
/// transcendental operations (logarithms and non-integer powers) go through
/// `Double`, because there is no exact `Decimal` equivalent.
enum DecimalMath {
    /// The largest value a `Decimal` can hold. Used as a stand-in for
    /// `FloatingPoint.infinity` when picking a minimum.
    static var greatestFiniteMagnitude: Decimal {
        Decimal.greatestFiniteMagnitude
    }
    
    /// Rounds `value` to `scale` decimal places using decimal rounding.
    static func rounded(_ value: Decimal, scale: Int = 0) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
    
    /// Returns whether `value` has no fractional part.
    static func isIntegral(_ value: Decimal) -> Bool {
        rounded(value) == value
    }
    
    /// Returns `value` as an `Int` when it is an integral value that fits.
    static func integerValue(_ value: Decimal) -> Int? {
        guard isIntegral(value),
              value >= Decimal(Int.min),
              value <= Decimal(Int.max)
                else { return nil }
        return NSDecimalNumber(decimal: value).intValue
    }
    
    /// Raises `base` to an integer exponent using decimal multiplication.
    ///
    /// Exponentiation by squaring keeps the calculation exact for every
    /// representable result—no binary floating-point round-trip is involved.
    static func power(_ base: Decimal, _ exponent: Int) -> Decimal {
        if exponent == 0 { return 1 }
        if exponent < 0 { return 1 / power(base, -exponent) }
        
        var result: Decimal = 1
        var factor = base
        var remaining = exponent
        
        while remaining > 0 {
            if remaining & 1 == 1 {
                result *= factor
            }
            remaining >>= 1
            if remaining > 0 {
                factor *= factor
            }
        }
        return result
    }
    
    /// Raises `base` to an arbitrary decimal exponent.
    ///
    /// Integral exponents stay exact. Fractional exponents are inherently
    /// irrational for most inputs, so they fall back to `Foundation.pow` and
    /// are converted back to `Decimal`.
    static func power(_ base: Decimal, _ exponent: Decimal) -> Decimal {
        if let integer = integerValue(exponent) {
            return power(base, integer)
        }
        return Decimal(Foundation.pow(base.doubleValue, exponent.doubleValue))
    }
    
    /// The natural logarithm of `value`, rounded to decimal precision.
    static func log(_ value: Decimal) -> Decimal {
        Decimal(Foundation.log(value.doubleValue))
    }
    
    /// The base-10 logarithm of `value`, rounded to decimal precision.
    static func log10(_ value: Decimal) -> Decimal {
        Decimal(Foundation.log10(value.doubleValue))
    }
    
    /// Returns whether `value` is a positive power of ten (`1`, `10`, `0.001`,
    /// ...), tested with exact decimal division rather than a logarithm.
    static func isPowerOfTen(_ value: Decimal) -> Bool {
        guard value > 0 else { return false }
        
        var remaining = value
        while remaining >= 10 {
            remaining /= 10
        }
        while remaining < 1 {
            remaining *= 10
        }
        return remaining == 1
    }
    
    /// Formats a decimal with a fixed number of fraction digits.
    ///
    /// This deliberately avoids `String(format:)`: `Decimal` is not a
    /// `CVarArg`, and bridging it through `NSDecimalNumber` that way produces
    /// incorrect output. A `NumberFormatter` renders the decimal directly and
    /// keeps formatting deterministic (no grouping, POSIX separators).
    static func format(_ value: Decimal, decimalPlaces: Int?, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .halfUp
            
        if let decimalPlaces = decimalPlaces {
            let places = max(0, decimalPlaces)
            formatter.minimumFractionDigits = places
            formatter.maximumFractionDigits = places
        } else {
            let actualPlaces = value.exponent < 0 ? abs(value.exponent) : 0
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = actualPlaces
        }
        
        return formatter.string(from: value as NSDecimalNumber) ?? value.description
    }

}

extension Decimal {
    /// The nearest `Double`, used only for transcendental operations and
    /// reciprocal conversions at API boundaries.
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

/// The SI prefixes used to synthesize metric siblings such as `km` and `mg`.
///
/// Keep this list in sync with `Sources/Math/units.sh`.
enum MetricPrefixes {
    static let all: [(symbol: String, value: Decimal)] = [
        ("Q", DecimalMath.power(10, 30)), ("R", DecimalMath.power(10, 27)),
        ("Y", DecimalMath.power(10, 24)), ("Z", DecimalMath.power(10, 21)),
        ("E", DecimalMath.power(10, 18)), ("P", DecimalMath.power(10, 15)),
        ("T", DecimalMath.power(10, 12)), ("G", DecimalMath.power(10, 9)),
        ("M", DecimalMath.power(10, 6)), ("k", DecimalMath.power(10, 3)),
        ("h", DecimalMath.power(10, 2)), ("da", DecimalMath.power(10, 1)),
        ("d", DecimalMath.power(10, -1)), ("c", DecimalMath.power(10, -2)),
        ("m", DecimalMath.power(10, -3)), ("u", DecimalMath.power(10, -6)),
        ("n", DecimalMath.power(10, -9)), ("p", DecimalMath.power(10, -12)),
        ("f", DecimalMath.power(10, -15)), ("a", DecimalMath.power(10, -18)),
        ("z", DecimalMath.power(10, -21)), ("y", DecimalMath.power(10, -24)),
        ("r", DecimalMath.power(10, -27)), ("q", DecimalMath.power(10, -30))
    ]
}

/// Shared formatting for typed and type-erased quantities.
enum QuantityFormatting {
    static func format(
        value: Decimal,
        unit: any MathUnit,
        decimalPlaces: Int?,
        includeSpace: Bool?,
        locale: Locale = .current
    ) -> String {
        let formattedValue = DecimalMath.format(value, decimalPlaces: decimalPlaces, locale: locale)

        let groupingSeparator = locale.groupingSeparator ?? ""
        let spaceCharacter = groupingSeparator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !groupingSeparator.isEmpty
            ? "\u{00A0}"
            : " "
        
        switch unit.symbolPosition {
        case .prefix:
            let space = includeSpace ?? false ? spaceCharacter : ""
            return "\(unit.symbol)\(space)\(formattedValue)"
            
        case .suffix:
            let defaultSpace = unit.symbol != "%"
            let space = includeSpace ?? defaultSpace ? spaceCharacter : ""
            return "\(formattedValue)\(space)\(unit.symbol)"
        }
    }
}
