//
//  NamedUnit.swift
//  Maths
//
//  Created by Hanna Skairipa on 29/05/26.
//

/// A unit with a fixed symbol and dimension, parameterized by its compile-time
/// dimension type.
///
/// `NamedUnit` is the unit type you use to define or recombine named units. It
/// carries a `Dim` generic parameter conforming to ``DimensionProtocol``, which
/// lets the compiler verify dimension compatibility at build time.
///
/// The hundreds of built-in units in ``Units`` are all `NamedUnit` instances—for
/// example `Units.metre` is a `NamedUnit<MathDimension.length>`. Use it yourself
/// to create a unit for a custom compile-time dimension:
///
/// ```swift
/// let lightYear = NamedUnit<MathDimension.length>(
///     symbol: "ly",
///     dimension: .length,
///     converter: LinearConverter(coefficient: 9_460_730_472_580_800)
/// )
/// ```
///
/// For custom runtime-only dimensions, use ``MathDimension/unknown`` as the
/// type parameter. See <doc:CustomDimensions>.
public struct NamedUnit<Dim: DimensionProtocol>: MathsUnit {
    /// The compile-time dimension type associated with this unit.
    public typealias Dimension = Dim

    /// The canonical symbol representing the unit, e.g. `"m"`.
    ///
    /// This value is locale-independent. Use ``displaySymbol`` for the symbol
    /// shown to people.
    public let symbol: String

    /// The stable key used to look up the unit's localized name and display
    /// symbol in `Localisable.xcstrings`.
    ///
    /// When `nil`, the unit uses ``symbol`` for both.
    public let localizationKey: String?

    /// The underlying physical dimension of this unit.
    public let dimension: PhysicalDimension

    /// The unit converter used to transform values of this unit to and from base units.
    public let converter: any UnitConverter

    /// The position where the unit symbol should be placed when formatting.
    public let symbolPosition: SymbolPosition

    /// Creates a named unit.
    ///
    /// - Parameters:
    ///   - symbol: The textual symbol for the unit, e.g. `"m"`.
    ///   - dimension: The physical dimension of the unit. Prefer `.length`,
    ///     `.time`, `.energy`, and friends for the built-in dimensions.
    ///   - converter: How values in this unit convert to and from the base unit.
    ///     Pass a ``LinearConverter`` for a scale, or an ``OffsetConverter``
    ///     for a scale plus offset (e.g. temperature scales).
    ///   - symbolPosition: Where the symbol is placed when formatting. Defaults
    ///     to `.prefix` for currency dimensions and `.suffix` otherwise.
    ///   - localizationKey: A stable key for the unit's localized name and
    ///     display symbol. Pass the same key used for the catalog entries
    ///     `unit.name.<key>` and `unit.symbol.<key>`. When `nil`, the unit is
    ///     not localized and falls back to `symbol`.
    public init(
        symbol: String,
        dimension: PhysicalDimension,
        converter: any UnitConverter,
        symbolPosition: SymbolPosition? = nil,
        localizationKey: String? = nil
    ) {
        self.symbol = symbol
        self.dimension = dimension
        self.converter = converter
        self.symbolPosition = symbolPosition ?? (dimension == .currency ? .prefix : .suffix)
        self.localizationKey = localizationKey
    }

    /// The localized, human-readable unit name, e.g. `"metre"`.
    ///
    /// Falls back to the canonical ``symbol`` when the unit has no
    /// ``localizationKey`` or the catalog has no entry for it.
    public var name: String {
        guard let localizationKey else { return symbol }
        return UnitLocalization.name(for: localizationKey, dimension: dimension)
    }

    /// The localized symbol to show when formatting, e.g. `"m"`.
    ///
    /// The canonical ``symbol`` is untouched; this property only affects what
    /// people see.
    public var displaySymbol: String {
        guard let localizationKey else { return symbol }
        return UnitLocalization.symbol(for: localizationKey, fallback: symbol)
    }

    /// The base unit for this dimension: the same symbol and dimension with an
    /// identity ``LinearConverter``.
    public var base: NamedUnit<Dim> {
        NamedUnit(
            symbol: symbol,
            dimension: dimension,
            converter: LinearConverter(coefficient: 1.0),
            symbolPosition: symbolPosition,
            localizationKey: localizationKey
        )
    }
}

extension NamedUnit: Equatable {
    /// Two named units are equal when they share a symbol and dimension.
    public static func == (lhs: NamedUnit<Dim>, rhs: NamedUnit<Dim>) -> Bool {
        lhs.symbol == rhs.symbol &&
        lhs.dimension == rhs.dimension
    }
}

extension NamedUnit: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(symbol)
        hasher.combine(dimension)
    }
}
