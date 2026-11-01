//
//  AnyMathUnit.swift
//  Math
//
//  Created by Hanna Skairipa on 11/1/26.
//

import Foundation

/// A type-erased unit.
///
/// `AnyMathUnit` stores everything a ``MathUnit`` needs—symbol, physical
/// dimension, converter, symbol position, identity, and conversion family—so
/// units from different dimensions can live in the same collection. It can wrap
/// any concrete unit:
///
/// ```swift
/// let units: [AnyMathUnit] = [
///     AnyMathUnit(Units.meter),
///     AnyMathUnit(Units.kilogram),
///     AnyMathUnit(Units.usd),
/// ]
/// ```
///
/// The erased unit still behaves like a normal unit: ``base`` returns an
/// identity-converted version, equality and hashing respect the original
/// identity, and ``AnyQuantity`` uses it for conversion, simplification, and
/// formatting.
public struct AnyMathUnit: MathUnit, Sendable, Hashable,
                           CustomStringConvertible, Codable {
    /// The compile-time dimension used by the type system.
    ///
    /// The real dimension is the instance property ``dimension``; the type-level
    /// value is necessarily neutral because one erased type covers every
    /// dimension.
    public typealias Dimension = AnyDimension

    /// The symbol representing the unit, e.g. `"m"`.
    public let symbol: String

    /// The underlying physical dimension of this unit.
    public let dimension: PhysicalDimension

    /// The unit converter used to transform values to and from base units.
    public let converter: any UnitConverter

    /// The position where the unit symbol is placed when formatting.
    public let symbolPosition: SymbolPosition

    /// A stable identifier for the original unit.
    public let identity: String

    /// The original unit's conversion family, if it has one.
    public let conversionFamily: String?

    private let baseProvider: @Sendable () -> AnyMathUnit

    /// The base reading of this unit.
    public var base: AnyMathUnit {
        baseProvider()
    }

    /// Erases a concrete unit.
    public init<U: MathUnit>(_ unit: U) {
        let baseUnit = unit.base

        self.init(
            symbol: unit.symbol,
            dimension: unit.dimension,
            converter: unit.converter,
            symbolPosition: unit.symbolPosition,
            identity: unit.identity,
            conversionFamily: unit.conversionFamily,
            baseProvider: { AnyMathUnit(baseUnit) }
        )
    }

    /// Erases an already-erased unit.
    public init(erasing unit: any MathUnit) {
        let baseUnit = unit.base

        self.init(
            symbol: unit.symbol,
            dimension: unit.dimension,
            converter: unit.converter,
            symbolPosition: unit.symbolPosition,
            identity: unit.identity,
            conversionFamily: unit.conversionFamily,
            baseProvider: { AnyMathUnit(erasing: baseUnit) }
        )
    }

    /// Creates a unit from its erased components.
    ///
    /// When no `baseProvider` is supplied, ``base`` keeps the same symbol and
    /// dimension but uses an identity converter, matching ``NamedUnit/base``.
    public init(
        symbol: String,
        dimension: PhysicalDimension,
        converter: any UnitConverter,
        symbolPosition: SymbolPosition? = nil,
        identity: String? = nil,
        conversionFamily: String? = nil,
        baseProvider: (@Sendable () -> AnyMathUnit)? = nil
    ) {
        let resolvedPosition = symbolPosition
            ?? (dimension == .currency ? .prefix : .suffix)
        let resolvedIdentity = identity
            ?? "\(symbol)|\(canonicalDimensionKey(dimension))"

        self.symbol = symbol
        self.dimension = dimension
        self.converter = converter
        self.symbolPosition = resolvedPosition
        self.identity = resolvedIdentity
        self.conversionFamily = conversionFamily
        self.baseProvider = baseProvider ?? {
            AnyMathUnit(
                symbol: symbol,
                dimension: dimension,
                converter: EmptyConverter(),
                symbolPosition: resolvedPosition,
                identity: "\(symbol)|\(canonicalDimensionKey(dimension))"
            )
        }
    }

    /// The unit's symbol, e.g. `"m"`.
    public var description: String {
        symbol
    }

    /// Two erased units are equal when their identities and dimensions match.
    public static func == (lhs: AnyMathUnit, rhs: AnyMathUnit) -> Bool {
        lhs.identity == rhs.identity && lhs.dimension == rhs.dimension
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
        hasher.combine(dimension)
    }
}

// MARK: - Codable

extension AnyMathUnit {
    private enum CodingKeys: String, CodingKey {
        case symbol
        case dimension
        case converter
        case symbolPosition
        case identity
        case conversionFamily
    }

    /// Decodes a fully functional erased unit, including its converter.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let symbol = try container.decode(String.self, forKey: .symbol)
        let dimension = try container.decode(PhysicalDimension.self, forKey: .dimension)
        let converter = try container.decode(AnyUnitConverterCodable.self, forKey: .converter).converter
        let symbolPosition = try container.decode(SymbolPosition.self, forKey: .symbolPosition)
        let identity = try container.decodeIfPresent(String.self, forKey: .identity)
        let conversionFamily = try container.decodeIfPresent(String.self, forKey: .conversionFamily)

        self.init(
            symbol: symbol,
            dimension: dimension,
            converter: converter,
            symbolPosition: symbolPosition,
            identity: identity,
            conversionFamily: conversionFamily
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(dimension, forKey: .dimension)
        try container.encode(AnyUnitConverterCodable(converter), forKey: .converter)
        try container.encode(symbolPosition, forKey: .symbolPosition)
        try container.encode(identity, forKey: .identity)
        try container.encodeIfPresent(conversionFamily, forKey: .conversionFamily)
    }
}

private func canonicalDimensionKey(_ dimension: PhysicalDimension) -> String {
    dimension.exponents
        .sorted { $0.key < $1.key }
        .map { "\($0.key)^\($0.value)" }
        .joined(separator: "*")
}
