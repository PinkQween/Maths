//
//  LinearConverter.swift
//  Maths
//
//  Created by Hanna Skairipa on 29/05/26.
//

import Foundation

/// A ``UnitConverter`` that scales values by a fixed coefficient.
///
/// Use a `LinearConverter` for units that share a zero point with the base unit,
/// such as `1 km = 1000 m` or `1 min = 60 s`:
///
/// ```swift
/// let minute = NamedUnit<MathDimension.time>(
///     symbol: "min",
///     dimension: .time,
///     converter: LinearConverter(coefficient: 60)
/// )
/// ```
///
/// For units with an additive offset (like Celsius), use an ``OffsetConverter``
/// instead.
public struct LinearConverter: UnitConverter {

    /// The factor applied to convert values to and from the base unit.
    public let coefficient: Decimal

    /// Creates a linear converter with a scale factor.
    ///
    /// - Parameter coefficient: The number of base units represented by one of
    ///   this unit. For example, `1000` for kilometers (one kilometer is 1000 metres).
    public init(coefficient: Decimal) {
        self.coefficient = coefficient
    }

    /// Multiplies `value` by the coefficient.
    public func convertToBase(_ value: Decimal) -> Decimal {
        value * coefficient
    }

    /// Divides `value` by the coefficient.
    public func convertFromBase(_ value: Decimal) -> Decimal {
        value / coefficient
    }
}

extension LinearConverter: Codable {}
