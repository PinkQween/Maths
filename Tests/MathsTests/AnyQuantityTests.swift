import Testing
@testable import Maths
import Foundation

@Suite struct AnyQuantityTests {
    @Test func decimalArithmeticIsExact() {
        let tenth = Decimal(string: "0.1")!
        let fifth = Decimal(string: "0.2")!
        let expected = Decimal(string: "0.3")!

        #expect(tenth + fifth == expected)

        let length1 = Quantity(value: 5.0, unit: Units.metre)
        let length2 = Quantity(value: 2.0, unit: Units.kilometer)
        let difference = length2 - length1
        #expect(difference.value == Decimal(string: "1.995")!)
    }

    @Test func largeUnitCoefficientsStayExact() {
        let megaparsecInMeters = Units.megaparsec.converter.convertToBase(1)
        #expect(
            megaparsecInMeters
                == Decimal(string: "30856775814913673000000")!
        )

        let planckLengthInMeters = Units.planckLength.converter.convertToBase(1)
        #expect(planckLengthInMeters == Decimal(string: "1.616255e-35")!)
    }

    @Test func formattingKeepsDecimalDigits() {
        let value = Decimal(string: "12345678901234567890.12")!
        let quantity = Quantity(value: value, unit: Units.metre)

        #expect(quantity.formatted() == "12,345,678,901,234,567,890.12 m")
        #expect(AnyQuantity(value: 2.5, unit: Units.kilogram).formatted(decimalPlaces: 1) == "2.5 kg")
        #expect(AnyQuantity(value: 1234.5, unit: Units.usd).formatted() == "$1,234.50")
        #expect(AnyQuantity(value: 12.5, unit: Units.percent).formatted() == "12.50%")
    }

    // MARK: - Conversion

    @Test func anyQuantityConvertsToTypedUnits() {
        let mass = AnyQuantity(value: 2, unit: Units.kilogram)
        let grams = mass.converted(to: Units.gram)

        #expect(grams.value == 2000)
        #expect(grams.unit.symbol == "g")
        #expect(grams.unit.dimension == .mass)
    }

    @Test func anyQuantityConvertsToErasedUnits() {
        let mass = AnyQuantity(value: 2, unit: Units.kilogram)
        let gram: any MathsUnit = Units.gram
        let grams = mass.converted(to: gram)

        #expect(grams.value == 2000)
        #expect(grams.symbol == "g")
        #expect(grams.dimension == .mass)
    }

    @Test func anyQuantityIncompatibleConversionReturnsSelfSafely() {
        let mass = AnyQuantity(value: 2, unit: Units.kilogram)
        let metre: any MathsUnit = Units.metre
        let unconverted = mass.converted(to: metre)

        #expect(unconverted == mass)
        #expect(unconverted.value == 2)
        #expect(unconverted.symbol == "kg")
        #expect(unconverted.dimension == .mass)
        #expect(!mass.isCompatible(with: metre))
    }

    @Test func anyQuantityEquivalentAcrossUnits() {
        let mile = AnyQuantity(value: 1, unit: Units.mile)
        let metres = AnyQuantity(value: Decimal(string: "1609.344")!, unit: Units.metre)

        #expect(mile.isCompatible(with: metres))
        #expect(mile.isEquivalent(to: metres))
    }

    @Test func countsOnlyConvertWithinTheirItemFamily() {
        let eggs = AnyQuantity(value: 1, unit: CountUnit(item: "egg"))
        let apples = AnyQuantity(value: 1, unit: CountUnit(item: "apple"))

        #expect(!eggs.isCompatible(with: apples))
    }

    // MARK: - Simplification

    @Test func anyQuantitySimplifiesToCleanestUnit() {
        let metres = AnyQuantity(value: 1000, unit: Units.metre)
        let simplified = metres.simplified()

        #expect(simplified.value == 1)
        #expect(simplified.symbol == "km")

        let dozens = AnyQuantity(
            value: 2,
            unit: CountUnit(item: "egg", symbol: "doz", factor: 12)
        )
        let eggs = dozens.simplified()

        #expect(eggs.value == 24)
        #expect(eggs.symbol == "egg")
        #expect(eggs.conversionFamily == "count:egg")
    }

    // MARK: - Arithmetic

    @Test func anyQuantityArithmeticKeepsTheLeftUnit() {
        let meters = AnyQuantity(value: 1, unit: Units.metre)
        let centimetres = AnyQuantity(value: 100, unit: Units.centimetre)

        let sum = meters + centimetres
        #expect(sum.value == 2)
        #expect(sum.symbol == "m")

        let difference = meters - centimetres
        #expect(difference.value == 0)
        #expect(difference.symbol == "m")

        let scaled = meters * 3
        #expect(scaled.value == 3)
        #expect(scaled.symbol == "m")
    }

    @Test func anyQuantityMultiplicationCombinesDimensions() {
        let distance = AnyQuantity(value: 2, unit: Units.metre)
        let duration = AnyQuantity(value: 3, unit: Units.second)

        let product = distance * duration
        #expect(product.value == 6)
        #expect(product.symbol == "(m*s)")
        #expect(product.dimension == .length + .time)

        let ratio = distance / duration
        #expect(ratio.symbol == "(m/s)")
        #expect(ratio.dimension == .speed)
    }

    // MARK: - Erasure and equality

    @Test func typedQuantityErasesAndRestores() {
        let quantity = Quantity(value: 5, unit: Units.kilometer)
        let erased = quantity.anyQuantity

        #expect(erased.value == 5)
        #expect(erased.symbol == "km")
        #expect(erased.anyUnit == AnyMathsUnit(Units.kilometer))

        let restored = erased.typed(as: NamedUnit<MathDimension.length>.self)
        #expect(restored == quantity)

        #expect(erased.typed(as: CountUnit.self) == nil)
    }

    @Test func equalityAndHashingUseUnitIdentity() {
        let one = AnyQuantity(value: 2, unit: Units.metre)
        let two = AnyQuantity(value: 2, unit: Units.metre)
        let differentValue = AnyQuantity(value: 3, unit: Units.metre)
        let differentUnit = AnyQuantity(value: 2, unit: Units.second)

        #expect(one == two)
        #expect(one != differentValue)
        #expect(one != differentUnit)
        #expect(Set([one, two]).count == 1)
    }

    // MARK: - AnyMathsUnit and AnyDimension

    @Test func anyMathsUnitCarriesUnitBehavior() {
        let kilometer = AnyMathsUnit(Units.kilometer)

        #expect(kilometer.symbol == "km")
        #expect(kilometer.dimension == .length)
        #expect(kilometer.identity == Units.kilometer.identity)
        #expect(kilometer.converter.convertToBase(2) == 2000)
        #expect(kilometer.base.converter.convertToBase(2) == 2)
        #expect(kilometer.description == "km")
    }

    @Test func anyDimensionStoresPhysicalDimension() {
        let length = AnyDimension(MathDimension.length.self)
        let runtimeLength = AnyDimension(.length)

        #expect(length == runtimeLength)
        #expect(length.physicalDimension == .length)
        #expect(length.description == "length^1")
        #expect(AnyDimension.dimension == .dimensionless)
    }

    // MARK: - Codable

    @Test func anyQuantityCodableRoundTrip() throws {
        let quantities = [
            AnyQuantity(value: 1, unit: Units.kilometer),
            AnyQuantity(value: Decimal(string: "98.6")!, unit: Units.fahrenheit),
            AnyQuantity(value: 2, unit: CountUnit(item: "egg", symbol: "doz", factor: 12)),
            AnyQuantity(value: Decimal(string: "1.5e-9")!, unit: Units.metre),
        ]

        let data = try JSONEncoder().encode(quantities)
        let decoded = try JSONDecoder().decode([AnyQuantity].self, from: data)

        #expect(decoded == quantities)
        #expect(decoded[1].converted(to: Units.fahrenheit).value == Decimal(string: "98.6")!)
        #expect(decoded[2].converted(to: Units.Count.each).value == 24)
        #expect(decoded[3].value == Decimal(string: "1.5e-9")!)
    }

    @Test func anyMathsUnitCodableRoundTrip() throws {
        let unit = AnyMathsUnit(erasing: Units.celsius)
        let data = try JSONEncoder().encode(unit)
        let decoded = try JSONDecoder().decode(AnyMathsUnit.self, from: data)

        #expect(decoded == unit)
        #expect(decoded.converter.convertToBase(0) == Decimal(string: "3.7712427435e-21")!)
        #expect(decoded.converter.convertFromBase(Decimal(string: "3.7712427435e-21")!) == 0)
    }
}
