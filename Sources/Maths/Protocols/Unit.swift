//
//  Unit.swift
//  Maths
//
//  Created by Hanna Skairipa on 29/05/26.
//

import Foundation

/// A protocol representing a type-level identifier for a physical dimension.
///
/// Conforming types provide the underlying runtime ``PhysicalDimension`` value.
/// The ``MathDimension`` namespace provides the built-in conforming types, such
/// as ``MathDimension/length`` and ``MathDimension/time``. Because the conforming
/// type is used as a generic parameter, you can attach "this dimension only"
/// constraints to generic code with `where U.Dimension == MathDimension.length`.
///
/// See <doc:CompileTimeSafety> to learn how to use these constraints.
public protocol DimensionProtocol {
    /// The runtime `PhysicalDimension` value represented by this type.
    static var dimension: PhysicalDimension { get }
}

/// The position where a unit's symbol is placed when formatting a quantity.
///
/// * ``SymbolPosition/prefix`` — the symbol comes before the value (e.g. `$10.00`).
/// * ``SymbolPosition/suffix`` — the symbol comes after the value (e.g. `10.00 m`).
///
/// Currency units default to `.prefix`; all other units default to `.suffix`.
public enum SymbolPosition: String, Sendable, Codable {
    /// The symbol appears before the value, like `$10.00`.
    case prefix
    /// The symbol appears after the value, like `10.00 m`.
    case suffix
}

/// A unit of measurement, such as a metre, a second, or a US dollar.
///
/// A unit is the "what" of a measurement. It pairs three pieces of information:
///
/// * ``symbol`` — the textual representation, e.g. `"m"` for metres.
/// * ``dimension`` — the physical property it measures, e.g. ``PhysicalDimension/length``.
/// * ``converter`` — how values in this unit relate to the base unit, so
///   quantities in different units can be converted freely.
///
/// You usually work with concrete units from the ``Units`` type rather than
/// conforming to `MathUnit` yourself. To define a unit for a custom dimension,
/// use ``NamedUnit``:
///
/// ```swift
/// let usd = NamedUnit<MathDimension.unknown>(
///     symbol: "$",
///     dimension: PhysicalDimension(exponents: ["USD": 1]),
///     converter: LinearConverter(coefficient: 1.0)
/// )
/// ```
///
/// - AssociatedType: `Dimension` — the compile-time dimension type, used for
///   type-safe generics. See ``DimensionProtocol``.
public protocol MathUnit: Sendable {
    /// The compile-time dimension type associated with this unit.
    associatedtype Dimension: DimensionProtocol

    /// The canonical symbol representing the unit, e.g. `"m"`.
    ///
    /// The canonical symbol is stable across locales. It is used for identity,
    /// encoding, and conversion. For the symbol shown to people, use
    /// ``displaySymbol``.
    var symbol: String { get }

    /// The localized, human-readable name of the unit, e.g. `"metre"`.
    ///
    /// Types that do not provide a localized name fall back to their canonical
    /// ``symbol``.
    var name: String { get }

    /// The symbol to show when formatting a quantity, localized for the
    /// current locale.
    ///
    /// This differs from ``symbol``, which stays canonical so that equality and
    /// serialization do not change with the user's language. Types without a
    /// localized symbol fall back to ``symbol``.
    var displaySymbol: String { get }

    /// The underlying physical dimension of this unit.
    var dimension: PhysicalDimension { get }

    /// The unit converter used to transform values of this unit to and from base units.
    var converter: any UnitConverter { get }

    /// The position where the unit symbol should be placed when formatting.
    var symbolPosition: SymbolPosition { get }

    /// The base unit for this unit's dimension.
    var base: Self { get }

    /// A stable identifier for this unit, used by ``Quantity`` equality and hashing.
    ///
    /// The default combines the unit's symbol with its physical dimension, which
    /// matches the historical behavior for named and composite units. Types that
    /// can share a symbol while representing different things—such as
    /// ``CountUnit``—override this with a more specific identity.
    var identity: String { get }

    /// An optional family that restricts conversion beyond a matching dimension.
    ///
    /// Most units have no family (`nil`), meaning any unit with the same
    /// dimension is convertible. Count units use this to distinguish, for
    /// example, eggs from apples while still treating both as dimensionless.
    /// When both units declare a family, the families must match; a `nil`
    /// family acts as a wildcard.
    var conversionFamily: String? { get }
}

public extension MathUnit {
    /// The unit's canonical symbol doubles as its name unless the type provides
    /// a localized name.
    var name: String { symbol }

    /// Units without a localized display symbol use their canonical symbol.
    var displaySymbol: String { symbol }

    /// Currency units place their symbol before the value; everything else
    /// places it after.
    var symbolPosition: SymbolPosition {
        dimension == .currency ? .prefix : .suffix
    }

    /// The default unit identity: the symbol plus the canonical dimension.
    var identity: String {
        "\(symbol)|\(canonicalDimensionKey(dimension))"
    }

    /// The default conversion family: none, so dimension alone decides
    /// compatibility.
    var conversionFamily: String? { nil }

    /// Returns whether this unit can be converted to `other`.
    ///
    /// Units must share a dimension. If both units declare a
    /// ``conversionFamily``, those families must also match. A `nil` family is
    /// a wildcard, so ordinary dimensionless units still interoperate with
    /// identified count units.
    ///
    /// ```swift
    /// let egg = CountUnit(item: "egg")
    /// let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
    /// let apple = CountUnit(item: "apple")
    ///
    /// egg.isCompatible(with: dozenEggs) // true
    /// egg.isCompatible(with: apple)     // false
    /// ```
    func isCompatible<Other: MathUnit>(with other: Other) -> Bool {
        guard dimension == other.dimension else { return false }

        switch (conversionFamily, other.conversionFamily) {
        case let (lhs?, rhs?):
            return lhs == rhs
        default:
            return true
        }
    }
}

/// A canonical, order-independent string for a dimension's exponents, used to
/// build stable unit identities.
private func canonicalDimensionKey(_ dimension: PhysicalDimension) -> String {
    dimension.exponents
        .sorted { $0.key < $1.key }
        .map { "\($0.key)^\($0.value)" }
        .joined(separator: "*")
}

/// Multiplies two units, returning a new ``CompositeUnit`` whose dimension is the
/// sum of their exponents.
///
/// For example, multiplying a metre by a second produces a `(m*s)` unit with a
/// `length + time` dimension.
public func * <U1: MathUnit, U2: MathUnit>(lhs: U1, rhs: U2) -> CompositeUnit {
    let newDimension = lhs.dimension * rhs.dimension
    let newSymbol = "(\(lhs.symbol)*\(rhs.symbol))"
    let lhsCoeff = lhs.converter.convertToBase(1.0)
    let rhsCoeff = rhs.converter.convertToBase(1.0)
    let compositeCoeff = lhsCoeff * rhsCoeff
    return CompositeUnit(
        symbol: newSymbol,
        dimension: newDimension,
        converter: LinearConverter(coefficient: compositeCoeff)
    )
}

/// Divides two units, returning a new ``CompositeUnit`` whose dimension is the
/// difference of their exponents.
///
/// For example, dividing a metre by a second produces a `(m/s)` unit with a
/// `length - time` (speed) dimension.
public func / <U1: MathUnit, U2: MathUnit>(lhs: U1, rhs: U2) -> CompositeUnit {
    let newDimension = lhs.dimension / rhs.dimension
    let newSymbol = "(\(lhs.symbol)/\(rhs.symbol))"
    let lhsCoeff = lhs.converter.convertToBase(1.0)
    let rhsCoeff = rhs.converter.convertToBase(1.0)
    let compositeCoeff = lhsCoeff / rhsCoeff
    return CompositeUnit(
        symbol: newSymbol,
        dimension: newDimension,
        converter: LinearConverter(coefficient: compositeCoeff)
    )
}
