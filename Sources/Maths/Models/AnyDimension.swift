//
//  AnyDimension.swift
//  Maths
//
//  Created by Hanna Skairipa on 01/11/26.
//

import Foundation

/// A type-erased compile-time dimension.
///
/// `AnyDimension` lets a runtime unit carry its ``PhysicalDimension`` while
/// still satisfying ``DimensionProtocol``. The instance property
/// ``physicalDimension`` is the real dimension; the protocol's static
/// ``dimension`` requirement cannot vary per instance, so it reports
/// ``PhysicalDimension/dimensionless`` as a neutral fallback.
///
/// ```swift
/// let stored = AnyDimension(PhysicalDimension.length)
/// let storedLength = AnyDimension(MathDimension.length.self)
/// stored == storedLength // true
/// ```
public struct AnyDimension: DimensionProtocol, Sendable, Hashable, Codable,
                            CustomStringConvertible {
    /// The neutral dimension used by the protocol requirement.
    public static var dimension: PhysicalDimension {
        .dimensionless
    }

    /// The actual physical dimension stored by this erased value.
    public let physicalDimension: PhysicalDimension

    /// Erases a compile-time dimension type.
    public init<D: DimensionProtocol>(_ dimensionType: D.Type) {
        self.init(D.dimension)
    }

    /// Erases a runtime physical dimension.
    public init(_ physicalDimension: PhysicalDimension) {
        self.physicalDimension = physicalDimension
    }

    /// The dimension's canonical description.
    public var description: String {
        canonicalDescription(physicalDimension)
    }

    /// Two erased dimensions are equal when their underlying dimensions are.
    public static func == (lhs: AnyDimension, rhs: AnyDimension) -> Bool {
        lhs.physicalDimension == rhs.physicalDimension
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(physicalDimension)
    }
}

/// A canonical, order-independent description of a dimension's exponents.
func canonicalDescription(_ dimension: PhysicalDimension) -> String {
    guard !dimension.exponents.isEmpty else { return "dimensionless" }

    return dimension.exponents
        .sorted { $0.key < $1.key }
        .map { "\($0.key)^\($0.value)" }
        .joined(separator: "*")
}
