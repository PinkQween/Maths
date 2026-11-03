//
//  RatioUnit.swift
//  Maths
//
//  Created by Hanna Skairipa on 29/05/26.
//

import Foundation

/// A manually-constructed unit expressing the *ratio* of one unit to another,
/// carrying both units as type parameters so the compiler can enforce which
/// side is which.
///
/// Unlike the dynamically-typed ``CompositeUnit`` — whose type-level dimension
/// is always ``MathDimension/unknown`` — a `RatioUnit` keeps its numerator and
/// denominator as two distinct generic parameters. That makes `USD / kg` a
/// different type from `kg / USD`, so a function can demand, for example, that
/// its denominator is a currency:
///
/// ```swift
/// let price = Units.usd.per(Units.kilogram)              // RatioUnit<…currency, …mass>
///
/// func totalCost<Num: MathsUnit, Den: MathsUnit>(
///     price: Quantity<RatioUnit<Num, Den>>,
///     amount: Quantity<Den>
/// ) -> Quantity<Num> where Num.Dimension == MathDimension.currency {
///     price * amount
/// }
///
/// let bill = totalCost(price: Quantity(value: 3.5, unit: price),
///                      amount: Quantity(value: 2, unit: Units.kilogram))
/// // Quantity<NamedUnit<MathDimension.currency>>: $7.00
/// ```
///
/// Building a ratio does not change values: the ratio's converter is the
/// numerator's base coefficient divided by the denominator's, so `3 USD / 2 kg`
/// retains its exact meaning when the unit is decomposed.
public struct RatioUnit<Numerator: MathsUnit, Denominator: MathsUnit>: MathsUnit, CustomStringConvertible {
    /// The ratio's type-level dimension is `unknown`; the real constraint lives
    /// in the `Numerator` and `Denominator` generic parameters.
    public typealias Dimension = MathDimension.unknown

    /// The numerator unit of the ratio, e.g. `Units.usd`.
    public let numerator: Numerator

    /// The denominator unit of the ratio, e.g. `Units.kilogram`.
    public let denominator: Denominator

    /// Creates a ratio unit from an explicit numerator and denominator.
    ///
    /// - Parameters:
    ///   - numerator: The unit on the top of the ratio.
    ///   - denominator: The unit on the bottom of the ratio.
    public init(numerator: Numerator, denominator: Denominator) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// The composite symbol, e.g. `"(usd/kg)"`.
    ///
    /// This canonical form is stable across locales.
    public var symbol: String {
        "(\(numerator.symbol)/\(denominator.symbol))"
    }

    /// The composite symbol using each side's localized display symbol.
    public var displaySymbol: String {
        "(\(numerator.displaySymbol)/\(denominator.displaySymbol))"
    }

    /// The ratio's physical dimension: the numerator's minus the denominator's.
    public var dimension: PhysicalDimension {
        numerator.dimension / denominator.dimension
    }

    /// The numerator's base coefficient divided by the denominator's.
    public var converter: any UnitConverter {
        LinearConverter(
            coefficient: numerator.converter.convertToBase(1.0)
                / denominator.converter.convertToBase(1.0)
        )
    }

    /// The ratio places its symbol after the value, like any composite unit.
    public var symbolPosition: SymbolPosition { .suffix }

    /// The ratio's identity includes both operand identities, so two ratios
    /// with the same printed symbol but different count families or scales
    /// remain distinct.
    public var identity: String {
        "(\(numerator.identity)/\(denominator.identity))"
    }

    /// The ratio's conversion family is derived from its operands. A ratio with
    /// any identified side (for example `$ / egg`) only converts to another
    /// ratio with the same identified sides; `$ / dozen` still matches
    /// `$ / egg` because the denominator's item family is unchanged.
    public var conversionFamily: String? {
        let numeratorFamily = numerator.conversionFamily
        let denominatorFamily = denominator.conversionFamily
        guard numeratorFamily != nil || denominatorFamily != nil else { return nil }
        return "ratio(\(numeratorFamily ?? "*")/\(denominatorFamily ?? "*"))"
    }

    /// The base ratio: the same units with identity converters.
    public var base: RatioUnit {
        RatioUnit(numerator: numerator.base, denominator: denominator.base)
    }

    /// The ratio's symbol, e.g. `"(usd/kg)"`.
    public var description: String {
        return symbol
    }
}

public extension MathsUnit {
    /// Returns this unit as the numerator of a ``RatioUnit`` over `denominator`.
    ///
    /// ```swift
    /// let pricePerMass = Units.usd.per(Units.kilogram)   // (usd/kg)
    /// let pricePerHour = Units.usd.per(Units.hour)       // (usd/hr)
    /// ```
    func per<Denominator: MathsUnit>(_ denominator: Denominator) -> RatioUnit<Self, Denominator> {
        RatioUnit(numerator: self, denominator: denominator)
    }
}

extension RatioUnit: Equatable {
    /// Two ratio units are equal when their numerator and denominator identities
    /// match. This keeps `$ / egg` distinct from `$ / apple` even though both
    /// print as a dimensionless ratio.
    public static func == (lhs: RatioUnit, rhs: RatioUnit) -> Bool {
        lhs.identity == rhs.identity
    }
}

extension RatioUnit: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
    }
}

extension RatioUnit: Codable where Numerator: Codable, Denominator: Codable {
    private enum CodingKeys: String, CodingKey {
        case numerator
        case denominator
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let numerator = try container.decode(Numerator.self, forKey: .numerator)
        let denominator = try container.decode(Denominator.self, forKey: .denominator)
        self.init(numerator: numerator, denominator: denominator)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(numerator, forKey: .numerator)
        try container.encode(denominator, forKey: .denominator)
    }
}
