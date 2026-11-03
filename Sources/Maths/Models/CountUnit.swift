//
//  CountUnit.swift
//  Maths
//
//  Created by Hanna Skairipa on 10/30/26.
//

import Foundation

/// A dimensionless unit for counting things, with an optional item identity.
///
/// ``CountUnit`` is designed for point-of-sale, blending, and inventory apps
/// where items are counted rather than measured: eggs, apples, bottles, cases,
/// trays, or anything else. Unlike the fixed catalog in ``Units``, you can
/// create as many count units as your app needs at runtime.
///
/// A count unit is still **dimensionless**, so it participates in ordinary
/// dimensional algebra: you can price something per count with
/// ``MathsUnit/per(_:)``, multiply the price by a count, and get money back.
///
/// ```swift
/// let egg = CountUnit(item: "egg")
/// let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
///
/// let carton = Quantity(value: 2, unit: dozenEggs)
/// print(carton.converted(to: egg).value) // 24
///
/// let pricePerEgg = Quantity(value: 0.25, unit: Units.usd.per(egg))
/// let total = pricePerEgg * carton            // $6.00
/// ```
///
/// ### Identity and families
///
/// The `item` is the unit's family. Two count units with the same item convert
/// freely, even when their scales differ (`egg` and `dozenEggs`). Two count
/// units with different items do **not** convert: eggs and apples are both
/// dimensionless, but they are not interchangeable.
///
/// ```swift
/// let apple = CountUnit(item: "apple")
///
/// egg.isCompatible(with: dozenEggs) // true
/// egg.isCompatible(with: apple)     // false
/// ```
///
/// A count unit created without an item is a *generic* count (``Units/Count``
/// contains common ones such as `each`, `pair`, `dozen`, and `gross`). Generic
/// counts act as a wildcard and interoperate with identified counts, which is
/// handy for shared counting scales.
///
/// - SeeAlso: <doc:CountingUnits>
public struct CountUnit: MathsUnit, Hashable, Codable, CustomStringConvertible {
    /// The compile-time dimension of every count: ``MathDimension/dimensionless``.
    public typealias Dimension = MathDimension.dimensionless

    /// The identity of the thing being counted, such as `"egg"` or `"apple"`.
    ///
    /// `nil` means this is a generic counting scale (for example a plain
    /// `dozen`) that can be applied to any item.
    public let item: String?

    /// The canonical symbol used for identity, e.g. `"egg"`, `"ea"`, or `"doz"`.
    public let symbol: String

    /// The optional catalog key for a localized name and display symbol.
    ///
    /// Built-in counting scales such as ``Units/dozen`` use this so their name
    /// and symbol can be translated. Count units you create at runtime leave it
    /// `nil` and fall back to ``symbol``.
    public let localizationKey: String?

    /// How many base counts one of this unit represents.
    ///
    /// The base count is the unit's own `factor: 1` reading, so a dozen has a
    /// factor of `12` and a case of `24` has a factor of `24`.
    public let factor: Decimal

    /// Counts are dimensionless.
    public var dimension: PhysicalDimension { .dimensionless }

    /// Converts this unit's reading into base counts by multiplying by `factor`.
    public var converter: any UnitConverter { LinearConverter(coefficient: factor) }

    /// Count symbols are displayed after the value, e.g. `2 dozen`.
    public var symbolPosition: SymbolPosition { .suffix }

    /// A stable identifier for this count unit.
    ///
    /// Two units with the same item, scale, and symbol have the same identity,
    /// even when they are separate instances. The item is the conversion
    /// family; the factor distinguishes `dozen` from `each`.
    public var id: String {
        "count:\(item ?? "*"):\(factor):\(symbol)"
    }

    /// The localized, human-readable name of the counting scale.
    public var name: String {
        guard let localizationKey else { return symbol }
        return UnitLocalization.name(for: localizationKey, dimension: .dimensionless)
    }

    /// The localized symbol to show when formatting, e.g. `"doz"`.
    public var displaySymbol: String {
        guard let localizationKey else { return symbol }
        return UnitLocalization.symbol(for: localizationKey, fallback: symbol)
    }

    /// Count units use ``id`` for quantity equality and hashing.
    public var identity: String { id }

    /// Count units only convert within the same item family.
    ///
    /// Generic count units (`item == nil`) return `nil`, which acts as a
    /// wildcard so shared scales like `dozen` can be used with any item.
    public var conversionFamily: String? {
        item.map { "count:\($0)" }
    }

    /// The count unit's localized display symbol, e.g. `"doz"`.
    public var description: String { displaySymbol }

    /// Creates an identified count unit for a specific item.
    ///
    /// - Parameters:
    ///   - item: The thing being counted, e.g. `"egg"`. This is also the
    ///     conversion family: counts of different items are not interchangeable.
    ///   - symbol: The display symbol. Defaults to `item`.
    ///   - factor: How many base counts one of this unit represents. Defaults
    ///     to `1`.
    ///
    /// ```swift
    /// let egg = CountUnit(item: "egg")
    /// let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
    /// ```
    public init(
        item: String,
        symbol: String? = nil,
        factor: Decimal = 1,
        localizationKey: String? = nil
    ) {
        self.init(
            optionalItem: item,
            symbol: symbol ?? item,
            factor: factor,
            localizationKey: localizationKey
        )
    }

    /// Creates a generic count unit that can be applied to any item.
    ///
    /// - Parameters:
    ///   - symbol: The display symbol, e.g. `"doz"`.
    ///   - factor: How many base counts one of this unit represents.
    ///
    /// ```swift
    /// let dozen = CountUnit(symbol: "doz", factor: 12)
    /// ```
    public init(symbol: String, factor: Decimal = 1, localizationKey: String? = nil) {
        self.init(
            optionalItem: nil,
            symbol: symbol,
            factor: factor,
            localizationKey: localizationKey
        )
    }

    /// Creates an identified count unit using the item name as its symbol.
    ///
    /// This is shorthand for `CountUnit(item: item)`:
    ///
    /// ```swift
    /// let egg = CountUnit("egg")
    /// ```
    public init(
        _ item: String,
        symbol: String? = nil,
        factor: Decimal = 1,
        localizationKey: String? = nil
    ) {
        self.init(
            item: item,
            symbol: symbol,
            factor: factor,
            localizationKey: localizationKey
        )
    }

    private init(
        optionalItem: String?,
        symbol: String,
        factor: Decimal,
        localizationKey: String? = nil
    ) {
        precondition(factor > 0, "CountUnit factor must be positive, got \(factor)")
        self.item = optionalItem
        self.symbol = symbol
        self.factor = factor
        self.localizationKey = localizationKey
    }

    /// The base count of this unit's family: the item's factor-1 reading, or
    /// ``Units/Count/each`` for a generic count.
    public var base: CountUnit {
        if let item {
            return CountUnit(item: item)
        }
        return Units.Count.each
    }

    /// Returns a unit for the same item at a different scale.
    ///
    /// ```swift
    /// let dozenEggs = CountUnit(item: "egg").scaled(by: 12, symbol: "doz")
    /// let caseOfEggs = dozenEggs.scaled(by: 30, symbol: "case") // 360 eggs
    /// ```
    ///
    /// - Parameters:
    ///   - scale: The multiplier applied to this unit's factor.
    ///   - symbol: The new display symbol. Defaults to the current symbol.
    /// - Returns: A new count unit in the same family.
    public func scaled(by scale: Decimal, symbol: String? = nil) -> CountUnit {
        // A different scale is a different unit, so it starts without a catalog
        // key and falls back to the canonical symbol.
        CountUnit(optionalItem: item, symbol: symbol ?? self.symbol, factor: factor * scale)
    }

    /// Returns this counting scale applied to a specific item.
    ///
    /// This is useful for turning a generic scale such as ``Units/Count/dozen``
    /// into an item-specific unit:
    ///
    /// ```swift
    /// let dozenEggs = Units.Count.dozen.forItem("egg", symbol: "doz")
    /// ```
    ///
    /// - Parameters:
    ///   - item: The thing being counted.
    ///   - symbol: The new display symbol. Defaults to the current symbol.
    /// - Returns: A new count unit in the given item's family.
    public func forItem(_ item: String, symbol: String? = nil) -> CountUnit {
        CountUnit(
            optionalItem: item,
            symbol: symbol ?? self.symbol,
            factor: factor,
            localizationKey: localizationKey
        )
    }

    /// Returns whether this unit counts the same item as `other`.
    ///
    /// Generic units (`item == nil`) are not considered the same item as an
    /// identified unit, even though they are compatible.
    public func isSameItem(as other: CountUnit) -> Bool {
        item == other.item
    }
}

// MARK: - Common Counting Scales

public extension Units {
    /// A namespace of common counting scales, from a single each to a million.
    ///
    /// These units are *generic*: they can be applied to any item. For
    /// item-specific inventory, create a ``CountUnit`` with an `item`:
    ///
    /// ```swift
    /// let dozenEggs = Units.Count.dozen.forItem("egg", symbol: "doz")
    /// ```
    ///
    /// The namespace conforms to ``MathsUnit`` only so leading-dot lookup such as
    /// `.count.dozen` works; its instance members are never used.
    enum Count: MathsUnit {
        /// The compile-time dimension of counting: dimensionless.
        public typealias Dimension = MathDimension.dimensionless

        /// Browse-only marker; never instantiated.
        public var symbol: String { "" }
        /// Counting is dimensionless.
        public var dimension: PhysicalDimension { .dimensionless }
        /// Count namespaces have no converter of their own.
        public var converter: any UnitConverter { EmptyConverter() }
        /// Unit namespaces cannot be used as standalone units.
        public var base: Self { fatalError("Unit namespaces cannot be used as standalone units") }

        /// A single item: the base generic count (`ea`).
        public static let each = CountUnit(symbol: "ea", localizationKey: "each")
        /// A single piece (`pc`), convertible with ``each``.
        public static let piece = CountUnit(symbol: "pc", localizationKey: "piece")
        /// Two items (`pair`).
        public static let pair = CountUnit(symbol: "pair", factor: 2, localizationKey: "pair")
        /// Two items (`couple`), convertible with ``pair``.
        public static let couple = CountUnit(symbol: "couple", factor: 2, localizationKey: "couple")
        /// Six items (`half-doz`).
        public static let halfDozen = CountUnit(symbol: "half-doz", factor: 6, localizationKey: "halfDozen")
        /// Twelve items (`doz`).
        public static let dozen = CountUnit(symbol: "doz", factor: 12, localizationKey: "dozen")
        /// Thirteen items (`baker-doz`), the baker's dozen.
        public static let bakerDozen = CountUnit(symbol: "baker-doz", factor: 13, localizationKey: "bakerDozen")
        /// Twenty items (`score`).
        public static let score = CountUnit(symbol: "score", factor: 20, localizationKey: "score")
        /// One hundred forty-four items (`gross`).
        public static let gross = CountUnit(symbol: "gross", factor: 144, localizationKey: "gross")
        /// Twelve gross, or 1,728 items (`great-gross`).
        public static let greatGross = CountUnit(symbol: "great-gross", factor: 1_728, localizationKey: "greatGross")
        /// One hundred items (`hundred`).
        public static let hundred = CountUnit(symbol: "hundred", factor: 100, localizationKey: "hundred")
        /// One thousand items (`thousand`).
        public static let thousand = CountUnit(symbol: "thousand", factor: 1_000, localizationKey: "thousand")
        /// One million items (`million`).
        public static let million = CountUnit(symbol: "million", factor: 1_000_000, localizationKey: "million")

        /// Every generic counting scale, for pickers and listings.
        public static let all: [any MathsUnit] = [
            each, piece, pair, couple, halfDozen, dozen, bakerDozen,
            score, gross, greatGross, hundred, thousand, million
        ]
    }
}

// MARK: - Flat Aliases

public extension Units {
    /// A single generic count (`ea`).
    static let each = Count.each
    /// A single generic piece (`pc`).
    static let piece = Count.piece
    /// Two generic items (`pair`).
    static let pair = Count.pair
    /// Two generic items (`couple`).
    static let couple = Count.couple
    /// Six generic items (`half-doz`).
    static let halfDozen = Count.halfDozen
    /// Twelve generic items (`doz`).
    static let dozen = Count.dozen
    /// Thirteen generic items (`baker-doz`).
    static let bakerDozen = Count.bakerDozen
    /// Twenty generic items (`score`).
    static let score = Count.score
    /// One hundred forty-four generic items (`gross`).
    static let gross = Count.gross
    /// One thousand seven hundred twenty-eight generic items (`great-gross`).
    static let greatGross = Count.greatGross
    /// One hundred generic items (`hundred`).
    static let hundred = Count.hundred
    /// One thousand generic items (`thousand`).
    static let thousand = Count.thousand
    /// One million generic items (`million`).
    static let million = Count.million
}

// MARK: - Leading-Dot Lookup

public extension CountUnit {
    /// The `Count` namespace, e.g. `Units.Count.all`.
    static var count: Units.Count.Type { Units.Count.self }

    static let each = Units.each
    static let piece = Units.piece
    static let pair = Units.pair
    static let couple = Units.couple
    static let halfDozen = Units.halfDozen
    static let dozen = Units.dozen
    static let bakerDozen = Units.bakerDozen
    static let score = Units.score
    static let gross = Units.gross
    static let greatGross = Units.greatGross
    static let hundred = Units.hundred
    static let thousand = Units.thousand
    static let million = Units.million
}

public extension MathsUnit where Self == CountUnit {
    /// The `Count` unit namespace, e.g. `.count.dozen`.
    static var count: Units.Count.Type { Units.Count.self }

    static var each: CountUnit { Units.each }
    static var piece: CountUnit { Units.piece }
    static var pair: CountUnit { Units.pair }
    static var couple: CountUnit { Units.couple }
    static var halfDozen: CountUnit { Units.halfDozen }
    static var dozen: CountUnit { Units.dozen }
    static var bakerDozen: CountUnit { Units.bakerDozen }
    static var score: CountUnit { Units.score }
    static var gross: CountUnit { Units.gross }
    static var greatGross: CountUnit { Units.greatGross }
    static var hundred: CountUnit { Units.hundred }
    static var thousand: CountUnit { Units.thousand }
    static var million: CountUnit { Units.million }
}

// MARK: - Count Conveniences

public extension Quantity where U == CountUnit {
    /// Restates this count in the base unit of its item family.
    ///
    /// Identified counts go to the item's `factor: 1` reading; generic counts
    /// go to ``Units/Count/each``. This is the reading an inventory system
    /// usually stores.
    ///
    /// ```swift
    /// let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
    /// let carton = Quantity(value: 2, unit: dozenEggs)
    /// print(carton.baseCount()) // 24 egg
    /// ```
    func baseCount() -> Quantity<CountUnit> {
        converted(to: unit.base)
    }

    /// Counts simplify to the base count of their item family.
    ///
    /// The general `simplified()` method picks the cleanest unit from the
    /// dimension's catalog. Counts are runtime-extensible, so there is no
    /// finite catalog to scan; the safe, stable reading is the family's
    /// factor-1 unit.
    ///
    /// ```swift
    /// let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
    /// print(Quantity(value: 2, unit: dozenEggs).simplified()) // 24 egg
    /// ```
    func simplified() -> Quantity<CountUnit> {
        baseCount()
    }
}
