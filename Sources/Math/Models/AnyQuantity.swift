//
//  AnyQuantity.swift
//  Math
//
//  Created by Hanna Skairipa on 10/31/26.
//

import Foundation

/// A type-erased ``Quantity`` that can be stored alongside quantities measured
/// in other dimensions.
///
/// Blends often mix ingredients that cannot be converted into each other—grams
/// of tea leaves, fluid ounces of milk, and a count of tea bags, for example.
/// `AnyQuantity` keeps each reading in its original unit so those ingredients can
/// live in the same collection.
///
/// Unlike ``Quantity``, an `AnyQuantity` has no compile-time dimension, so its
/// compatibility checks happen at runtime. Everything else works the same way:
/// it converts, simplifies, formats, and participates in arithmetic.
///
/// ```swift
/// let ingredients: [AnyQuantity] = [
///     AnyQuantity(value: 250, unit: Units.gram),
///     AnyQuantity(value: 8, unit: Units.fluidOunce),
///     AnyQuantity(value: 2, unit: CountUnit(item: "tea bag")),
/// ]
///
/// for ingredient in ingredients {
///     print(ingredient.simplified()) // 250.00 g, 8.00 fl oz, 2.00 tea bag
/// }
/// ```
public struct AnyQuantity: Sendable, Hashable, CustomStringConvertible, Codable {
    /// The numeric magnitude of the quantity in ``unit``.
    public let value: Decimal

    /// The unit of measure for ``value``.
    public let unit: any MathUnit

    /// Creates a quantity with a value and an erased unit.
    public init(value: Decimal, unit: any MathUnit) {
        self.value = value
        self.unit = unit
    }

    /// Erases a strongly typed ``Quantity``.
    public init<U: MathUnit>(_ quantity: Quantity<U>) {
        self.init(value: quantity.value, unit: quantity.unit)
    }

    /// A quantity of nothing in a unit.
    public init(_ value: Decimal, _ unit: any MathUnit) {
        self.init(value: value, unit: unit)
    }

    /// The type-erased unit, for storing this quantity's unit in unit lists.
    public var anyUnit: AnyMathUnit {
        AnyMathUnit(erasing: unit)
    }

    /// The value converted into the dimension's base unit.
    public var baseValue: Decimal {
        unit.converter.convertToBase(value)
    }

    /// The physical dimension of the quantity.
    public var dimension: PhysicalDimension {
        unit.dimension
    }

    /// The unit's display symbol.
    public var symbol: String {
        unit.symbol
    }

    /// The unit's stable identity, used by equality and hashing.
    public var identity: String {
        unit.identity
    }

    /// The unit's conversion family, if it declares one.
    public var conversionFamily: String? {
        unit.conversionFamily
    }

    // MARK: - Conversion

    /// Converts this quantity to a concrete unit of the same dimension.
    ///
    /// ```swift
    /// let mass = AnyQuantity(value: 2, unit: Units.kilogram)
    /// let grams = mass.converted(to: Units.gram) // Quantity<NamedUnit<MathDimension.mass>>
    /// ```
    public func converted<Target: MathUnit>(to target: Target) -> Quantity<Target> {
        precondition(
            Self.areCompatible(unit, target),
            "Cannot convert \(symbol) to \(target.symbol): incompatible dimensions or families"
        )

        let targetValue = target.converter.convertFromBase(baseValue)
        return Quantity(value: targetValue, unit: target)
    }

    /// Converts this quantity to another erased unit of the same dimension.
    public func converted(to target: any MathUnit) -> AnyQuantity {
        precondition(
            Self.areCompatible(unit, target),
            "Cannot convert \(symbol) to \(target.symbol): incompatible dimensions or families"
        )

        let targetValue = target.converter.convertFromBase(baseValue)
        return AnyQuantity(value: targetValue, unit: target)
    }

    /// Returns `true` when both quantities describe the same kind of thing.
    ///
    /// In addition to matching dimensions, this honors a unit's conversion
    /// family, so counts of tea bags and counts of cinnamon sticks stay
    /// separate even though both are dimensionless.
    public func isCompatible(with other: AnyQuantity) -> Bool {
        Self.areCompatible(unit, other.unit)
    }

    /// Returns whether this quantity is physically equivalent to another,
    /// within a tolerance expressed in this quantity's unit.
    public func isEquivalent(
        to other: AnyQuantity,
        tolerance: Decimal = 1e-12
    ) -> Bool {
        guard isCompatible(with: other) else { return false }
        let converted = other.converted(to: unit)
        return abs(value - converted.value) <= tolerance
    }

    // MARK: - Simplification

    /// Restates this quantity in the unit that gives the cleanest reading.
    ///
    /// The picker walks the dimension's catalog (including SI-prefixed metric
    /// siblings) and prefers the smallest whole-number reading, falling back to
    /// the reading closest to a whole number. Count units simplify to the
    /// factor-1 unit of their item family instead of leaking into unrelated
    /// dimensionless units.
    ///
    /// ```swift
    /// AnyQuantity(value: 1000, unit: Units.meter).simplified() // 1 km
    /// AnyQuantity(value: 2, unit: CountUnit(item: "egg", symbol: "doz", factor: 12))
    ///     .simplified() // 24 egg
    /// ```
    public func simplified() -> AnyQuantity {
        // Counts are runtime-extensible, so there is no finite catalog to scan.
        // The stable reading is the family's factor-1 unit.
        if let count = unit as? CountUnit {
            return converted(to: count.base)
        }

        if value == 0 {
            return baseQuantity()
        }

        let tolerance: Decimal = 1e-9
        let candidates = simplifiedCandidates()

        var whole: (unit: AnyMathUnit, reading: Decimal)?
        var wholeMagnitude = DecimalMath.greatestFiniteMagnitude

        var fractional: (unit: AnyMathUnit, reading: Decimal)?
        var fractionalDistance = DecimalMath.greatestFiniteMagnitude
        var fractionalMagnitude = DecimalMath.greatestFiniteMagnitude

        for candidate in candidates where isInSameReadingFamily(candidate) {
            let reading = candidate.converter.convertFromBase(baseValue)
            let rounded = DecimalMath.rounded(reading)
            let distance = abs(reading - rounded)
            let isWhole = distance <= tolerance * max(Decimal(1), abs(rounded))
            let magnitude = abs(reading)

            if isWhole && magnitude >= 1 {
                if magnitude < wholeMagnitude {
                    wholeMagnitude = magnitude
                    whole = (candidate, reading)
                }
            } else if distance < fractionalDistance - tolerance
                || (abs(distance - fractionalDistance) <= tolerance
                    && magnitude < fractionalMagnitude) {
                fractionalDistance = distance
                fractionalMagnitude = magnitude
                fractional = (candidate, reading)
            }
        }

        if let whole {
            return AnyQuantity(value: whole.reading, unit: whole.unit)
        }
        if let fractional {
            return AnyQuantity(value: fractional.reading, unit: fractional.unit)
        }
        return baseQuantity()
    }

    /// The catalog units for this dimension plus their SI-prefixed siblings.
    private func simplifiedCandidates() -> [AnyMathUnit] {
        var seen = Set<String>()
        var result: [AnyMathUnit] = []

        func add(_ unit: any MathUnit) {
            guard !seen.contains(unit.symbol) else { return }
            seen.insert(unit.symbol)
            result.append(AnyMathUnit(erasing: unit))
        }

        for candidate in Units.units(for: unit.dimension) {
            add(candidate)

            let baseCoefficient = candidate.converter.convertToBase(1.0)
            guard DecimalMath.isPowerOfTen(baseCoefficient) else { continue }

            for prefix in MetricPrefixes.all {
                add(AnyMathUnit(
                    symbol: prefix.symbol + candidate.symbol,
                    dimension: candidate.dimension,
                    converter: LinearConverter(
                        coefficient: baseCoefficient * prefix.value
                    ),
                    symbolPosition: candidate.symbolPosition
                ))
            }
        }

        return result
    }

    /// `simplified()` only restates a quantity among units that read the same
    /// kind of thing, so counts never simplify into radians or percentages.
    private func isInSameReadingFamily(_ other: any MathUnit) -> Bool {
        guard unit.dimension == other.dimension else { return false }

        if let lhs = unit as? CountUnit {
            guard let rhs = other as? CountUnit else { return false }
            return lhs.isCompatible(with: rhs)
        }

        guard let family = unit.conversionFamily else { return true }
        return other.conversionFamily == family
    }

    private func baseQuantity() -> AnyQuantity {
        if !(unit is CountUnit),
           unit.conversionFamily == nil,
           let base = Units.units(for: unit.dimension).first {
            let reading = base.converter.convertFromBase(
                unit.converter.convertToBase(value)
            )
            return AnyQuantity(value: reading, unit: base)
        }

        return AnyQuantity(value: value, unit: unit.base)
    }

    // MARK: - Arithmetic

    /// Adds another compatible quantity, keeping this quantity's unit.
    public func adding(_ other: AnyQuantity) -> AnyQuantity {
        precondition(
            isCompatible(with: other),
            "Cannot add \(other.symbol) to \(symbol)"
        )

        let otherValue = unit.converter.convertFromBase(other.baseValue)
        return AnyQuantity(value: value + otherValue, unit: unit)
    }

    /// Subtracts another compatible quantity, keeping this quantity's unit.
    public func subtracting(_ other: AnyQuantity) -> AnyQuantity {
        precondition(
            isCompatible(with: other),
            "Cannot subtract \(other.symbol) from \(symbol)"
        )

        let otherValue = unit.converter.convertFromBase(other.baseValue)
        return AnyQuantity(value: value - otherValue, unit: unit)
    }

    /// Multiplies two quantities, combining their dimensions.
    public func multiplied(by other: AnyQuantity) -> AnyQuantity {
        let newDimension = dimension + other.dimension
        let newSymbol = "(\(symbol)*\(other.symbol))"
        let coefficient = unit.converter.convertToBase(1.0)
            * other.unit.converter.convertToBase(1.0)
        let newUnit = AnyMathUnit(
            symbol: newSymbol,
            dimension: newDimension,
            converter: LinearConverter(coefficient: coefficient)
        )

        return AnyQuantity(value: value * other.value, unit: newUnit)
    }

    /// Divides two quantities, dividing their dimensions.
    public func divided(by other: AnyQuantity) -> AnyQuantity {
        let newDimension = dimension - other.dimension
        let newSymbol = "(\(symbol)/\(other.symbol))"
        let coefficient = unit.converter.convertToBase(1.0)
            / other.unit.converter.convertToBase(1.0)
        let newUnit = AnyMathUnit(
            symbol: newSymbol,
            dimension: newDimension,
            converter: LinearConverter(coefficient: coefficient)
        )

        return AnyQuantity(value: value / other.value, unit: newUnit)
    }

    /// Scales this quantity by a decimal scalar, preserving its unit.
    public func multiplied(by scalar: Decimal) -> AnyQuantity {
        AnyQuantity(value: value * scalar, unit: unit)
    }

    /// Divides this quantity by a decimal scalar, preserving its unit.
    public func divided(by scalar: Decimal) -> AnyQuantity {
        AnyQuantity(value: value / scalar, unit: unit)
    }

    /// Returns the quantity as a strongly typed `Quantity` when the unit is
    /// stored as `U`.
    public func typed<U: MathUnit>(as type: U.Type = U.self) -> Quantity<U>? {
        guard let unit = unit as? U else { return nil }
        return Quantity(value: value, unit: unit)
    }

    // MARK: - Formatting

    /// Formats the value with its unit symbol on the correct side.
    ///
    /// - Parameters:
    ///   - decimalPlaces: The number of fraction digits (default `2`).
    ///   - includeSpace: Overrides the default spacing rules. Prefix symbols
    ///     default to no space; suffix symbols default to a space, except `%`.
    public func formatted(
        decimalPlaces: Int? = nil,
        includeSpace: Bool? = nil
    ) -> String {
        QuantityFormatting.format(
            value: value,
            unit: unit,
            decimalPlaces: decimalPlaces,
            includeSpace: includeSpace
        )
    }

    /// The formatted quantity, e.g. `"2.00 kg"`.
    public var description: String {
        formatted()
    }

    // MARK: - Equality

    public static func == (lhs: AnyQuantity, rhs: AnyQuantity) -> Bool {
        lhs.value == rhs.value
            && lhs.unit.identity == rhs.unit.identity
            && lhs.dimension == rhs.dimension
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(unit.identity)
        hasher.combine(dimension)
    }

    // MARK: - Helpers

    private static func areCompatible(
        _ lhs: any MathUnit,
        _ rhs: any MathUnit
    ) -> Bool {
        guard lhs.dimension == rhs.dimension else { return false }

        switch (lhs.conversionFamily, rhs.conversionFamily) {
        case let (lhsFamily?, rhsFamily?):
            return lhsFamily == rhsFamily
        default:
            return true
        }
    }
}

// MARK: - Codable

extension AnyQuantity {
    private enum CodingKeys: String, CodingKey {
        case value
        case unit
    }

    /// Decodes a quantity from its value and fully erased unit.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Decimal.self, forKey: .value)
        let unit = try container.decode(AnyMathUnit.self, forKey: .unit)
        self.init(value: value, unit: unit)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(anyUnit, forKey: .unit)
    }
}

// MARK: - Operators

public extension AnyQuantity {
    static func + (lhs: AnyQuantity, rhs: AnyQuantity) -> AnyQuantity {
        lhs.adding(rhs)
    }

    static func - (lhs: AnyQuantity, rhs: AnyQuantity) -> AnyQuantity {
        lhs.subtracting(rhs)
    }

    static func * (lhs: AnyQuantity, rhs: AnyQuantity) -> AnyQuantity {
        lhs.multiplied(by: rhs)
    }

    static func / (lhs: AnyQuantity, rhs: AnyQuantity) -> AnyQuantity {
        lhs.divided(by: rhs)
    }

    static func * (lhs: AnyQuantity, rhs: Decimal) -> AnyQuantity {
        lhs.multiplied(by: rhs)
    }

    static func * (lhs: Decimal, rhs: AnyQuantity) -> AnyQuantity {
        rhs.multiplied(by: lhs)
    }

    static func / (lhs: AnyQuantity, rhs: Decimal) -> AnyQuantity {
        lhs.divided(by: rhs)
    }
}

// MARK: - Typed Conveniences

public extension Quantity {
    /// This quantity with its compile-time dimension erased.
    var anyQuantity: AnyQuantity {
        AnyQuantity(self)
    }

    /// Alias for ``anyQuantity``, for call sites that prefer the noun form.
    var erased: AnyQuantity {
        anyQuantity
    }
}
