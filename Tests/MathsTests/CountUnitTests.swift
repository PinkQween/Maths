import Testing
@testable import Maths
import Foundation

@Suite struct CountUnitTests {
    @Test func arbitraryCountUnitsAreIdentifiable() {
        let egg = CountUnit(item: "egg")
        let eggAgain = CountUnit(item: "egg")
        let apple = CountUnit(item: "apple")

        #expect(egg == eggAgain)
        #expect(egg != apple)
        #expect(egg.id == eggAgain.id)
        #expect(egg.id != apple.id)
        #expect(egg.dimension == .dimensionless)
        #expect(egg.symbol == "egg")
        #expect(egg.factor == 1)
        #expect(egg.isSameItem(as: eggAgain))
        #expect(!egg.isSameItem(as: apple))
    }

    @Test func sameItemConvertsAcrossScales() {
        let egg = CountUnit(item: "egg")
        let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
        let carton = Quantity(value: 2, unit: dozenEggs)

        #expect(egg.isCompatible(with: dozenEggs))
        #expect(carton.converted(to: egg).value == 24)
        #expect(carton.baseCount().value == 24)
        #expect(carton.baseCount().unit == egg)
    }

    @Test func differentItemsAreNotCompatible() {
        let egg = CountUnit(item: "egg")
        let apple = CountUnit(item: "apple")
        let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)

        #expect(!egg.isCompatible(with: apple))
        #expect(egg.isCompatible(with: dozenEggs))
        // Generic counts are wildcards, so they work with any item.
        #expect(Units.Count.dozen.isCompatible(with: egg))
    }

    @Test func genericCountingScalesConvert() {
        #expect(Quantity(value: 1, unit: Units.Count.dozen)
            .converted(to: Units.Count.each).value == 12)
        #expect(Quantity(value: 1, unit: Units.Count.gross)
            .converted(to: Units.Count.dozen).value == 12)
        #expect(Quantity(value: 2, unit: Units.dozen)
            .converted(to: Units.each).value == 24)

        let dozenEggs = Units.Count.dozen.forItem("egg", symbol: "doz")
        #expect(dozenEggs.item == "egg")
        #expect(dozenEggs.factor == 12)
        #expect(dozenEggs.base == CountUnit(item: "egg"))
        #expect(Units.Count.dozen.base == Units.Count.each)
        #expect(Quantity(value: 1, unit: dozenEggs)
            .converted(to: CountUnit(item: "egg")).value == 12)
    }

    @Test func scalingBuildsArbitraryCountUnits() {
        let egg = CountUnit(item: "egg")
        let dozenEggs = egg.scaled(by: 12, symbol: "doz")
        let caseOfEggs = dozenEggs.scaled(by: 30, symbol: "case")

        #expect(dozenEggs.factor == 12)
        #expect(caseOfEggs.factor == 360)
        #expect(caseOfEggs.item == "egg")
        #expect(Quantity(value: 1, unit: caseOfEggs).converted(to: egg).value == 360)
    }

    @Test func perCountPricingCancelsCounts() {
        let egg = CountUnit(item: "egg")
        let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
        let pricePerEgg = Quantity(value: 0.25, unit: Units.usd.per(egg))
        let carton = Quantity(value: 2, unit: dozenEggs)

        let cost = pricePerEgg * carton
        #expect(cost.unit == Units.usd)
        #expect(abs(cost.value - 6.0) < 1e-12)

        // A generic per-dozen price can be applied to an identified count.
        let pricePerDozen = Quantity(value: 3.0, unit: Units.usd.per(Units.Count.dozen))
        let genericCost = pricePerDozen * carton
        #expect(abs(genericCost.value - 6.0) < 1e-12)

        // Ratio families keep per-egg and per-apple prices apart, while
        // different egg scales remain compatible.
        let pricePerDozenEggs = Units.usd.per(dozenEggs)
        let pricePerApple = Units.usd.per(CountUnit(item: "apple"))
        #expect(pricePerEgg.unit.isCompatible(with: pricePerDozenEggs))
        #expect(!pricePerEgg.unit.isCompatible(with: pricePerApple))
    }

    @Test func blendingCountsUsesTheLeftHandUnit() {
        let egg = CountUnit(item: "egg")
        let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)

        let total = Quantity(value: 5, unit: egg) + Quantity(value: 2, unit: dozenEggs)
        #expect(total.value == 29)
        #expect(total.unit == egg)

        let restated = Quantity(value: 5, unit: egg) + Quantity(value: 1, unit: dozenEggs)
        let expectedDozen: Decimal = 17.0 / 12.0
        #expect(restated.converted(to: dozenEggs).value == expectedDozen)
    }

    @Test func quantityEqualityUsesCountIdentity() {
        let eggEach = CountUnit(item: "egg", symbol: "each")
        let eggEachAgain = CountUnit(item: "egg", symbol: "each")
        let appleEach = CountUnit(item: "apple", symbol: "each")

        #expect(eggEach == eggEachAgain)
        #expect(eggEach != appleEach)
        #expect(Quantity(value: 1, unit: eggEach) == Quantity(value: 1, unit: eggEachAgain))
        #expect(Quantity(value: 1, unit: eggEach) != Quantity(value: 1, unit: appleEach))

        let keys: [Quantity<CountUnit>: String] = [
            Quantity(value: 1, unit: eggEach): "egg",
            Quantity(value: 1, unit: appleEach): "apple",
        ]
        #expect(keys[Quantity(value: 1, unit: eggEachAgain)] == "egg")
        #expect(keys.count == 2)
    }

    @Test func zeroAndCatalogLookupWorkForCounts() {
        let zero: Quantity<CountUnit> = .zero
        #expect(zero.value == 0)
        #expect(zero.unit == Units.Count.each)

        let dimensionless = Units.units(for: .dimensionless)
        #expect(dimensionless.contains { ($0 as? CountUnit) == Units.Count.dozen })
    }

    @Test func countUnitsCodableRoundTrip() throws {
        let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
        let carton = Quantity(value: 2, unit: dozenEggs)

        let data = try JSONEncoder().encode(carton)
        let decoded = try JSONDecoder().decode(Quantity<CountUnit>.self, from: data)

        #expect(decoded == carton)
        #expect(decoded.unit.item == "egg")
        #expect(decoded.unit.symbol == "doz")
        #expect(decoded.unit.factor == 12)
    }

    @Test func simplifiedDoesNotLeaveTheCountFamily() {
        let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
        let simplified = Quantity(value: 1, unit: dozenEggs).simplified()

        #expect(simplified.value == 12)
        #expect(simplified.unit == CountUnit(item: "egg"))
        #expect(simplified.unit.dimension == .dimensionless)
    }

    @Test func leadingDotCountLookup() {
        let dozen = Quantity(value: 1, unit: .dozen)
        let dozenEggs = Quantity(value: 1, unit: .count.dozen.forItem("egg"))

        #expect(dozen.unit == Units.Count.dozen)
        #expect(dozen.converted(to: .each).value == 12)
        #expect(dozenEggs.unit.item == "egg")
        #expect(dozenEggs.converted(to: CountUnit(item: "egg")).value == 12)
    }
}
