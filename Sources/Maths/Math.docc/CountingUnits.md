# Counting Units for Inventory and Blending

Create unlimited, identifiable dimensionless units for counting eggs, apples,
bottles, cases, and anything else your point-of-sale or inventory app tracks.

## Overview

Some quantities are measured; others are counted. A recipe uses 3 eggs, a
carton holds 12, and a case holds 360. Counts are **dimensionless**—they have no
meters, grams, or seconds—but they still need identity: eggs and apples are not
interchangeable just because both are dimensionless.

``CountUnit`` is a runtime-extensible count unit. There is no fixed catalog, so
you can create as many item-specific count units as your app needs:

```swift
import Math

let egg = CountUnit(item: "egg")
let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
let caseOfEggs = CountUnit(item: "egg", symbol: "case", factor: 360)

let apple = CountUnit(item: "apple")
let caseOfApples = CountUnit(item: "apple", symbol: "case", factor: 120)
```

Every count unit is still dimensionless, so it works with the rest of `Math`:
per-count prices, ratios, blending, and inventory totals.

## Quick start

```swift
import Math

// 1. Create item-specific count units at runtime.
let egg = CountUnit(item: "egg")
let dozenEggs = CountUnit(item: "egg", symbol: "doz", factor: 12)
let caseOfEggs = CountUnit(item: "egg", symbol: "case", factor: 360)

// 2. Count quantities.
let carton = Quantity(value: 2, unit: dozenEggs)
let loose = Quantity(value: 5, unit: egg)

// 3. Convert within the same item family.
carton.converted(to: egg) // 24 egg
carton.baseCount()        // 24 egg

// 4. Blend counts; the right-hand side converts to the left-hand unit.
let total = loose + carton                     // 29 egg
let inCartons = total.converted(to: dozenEggs) // 2.4166... doz

// 5. Price per count; the count cancels and leaves currency.
let pricePerEgg = Quantity(value: 0.25, unit: Units.usd.per(egg))
let cost = pricePerEgg * carton // $6.00

// 6. Generic scales act as wildcards.
let pricePerDozen = Quantity(value: 3.00, unit: Units.usd.per(Units.Count.dozen))
pricePerDozen * carton // $6.00

// 7. Generic counts and leading-dot lookup.
let dozens = Quantity(value: 2, unit: .dozen)
dozens.converted(to: .each) // 24 ea

// 8. Different items stay separate.
let apple = CountUnit(item: "apple")
egg.isCompatible(with: apple) // false
```

## Item families

The `item` is the unit's **conversion family**. Units in the same family convert
freely, even when their scales differ:

```swift
let carton = Quantity(value: 2, unit: dozenEggs)
print(carton.converted(to: egg).value) // 24
print(carton.baseCount().value)        // 24 (the family's factor-1 reading)
```

Units in different families do not convert, so eggs cannot silently become
apples:

```swift
egg.isCompatible(with: dozenEggs) // true
egg.isCompatible(with: apple)     // false
```

A count unit created without an item is a **generic** counting scale. Generic
counts act as a wildcard, so shared scales work with any item:

```swift
let dozen = Units.Count.dozen       // generic "doz", factor 12
let dozenEggs = dozen.forItem("egg", symbol: "doz")
let dozenApples = dozen.forItem("apple", symbol: "doz")
```

## Per-count pricing

Because a count unit conforms to ``MathUnit``, you can price anything per count
with ``MathUnit/per(_:)``. The count cancels exactly like any other unit:

```swift
let pricePerEgg = Quantity(value: 0.25, unit: Units.usd.per(egg))
let carton = Quantity(value: 2, unit: dozenEggs)

let total = pricePerEgg * carton
print(total.formatted()) // $6.00
```

The ratio keeps the count family, so a price per egg cannot accidentally be
applied to apples. A generic per-dozen price can still be applied to any item:

```swift
let pricePerDozen = Quantity(value: 3.00, unit: Units.usd.per(Units.Count.dozen))
let cost = pricePerDozen * carton // $6.00
```

## Blending and inventory

Addition converts the right-hand side into the left-hand side's unit, so
inventory and recipe totals stay in whatever count scale you choose:

```swift
let recipe = Quantity(value: 5, unit: egg)
           + Quantity(value: 2, unit: dozenEggs)
print(recipe) // 29.00 egg

let cartons = recipe.converted(to: dozenEggs)
print(cartons.value) // 2.4166...
```

Storing ``Quantity/baseCount()`` gives you a stable, factor-1 reading for
database rows and stock counts:

```swift
let stock = Quantity(value: 3, unit: caseOfEggs).baseCount()
print(stock) // 1080.00 egg
```

## Built-in generic scales

``Units/Count`` contains common counting scales that are not tied to an item:

| Unit | Symbol | Factor |
|------|--------|--------|
| ``Units/Count/each`` | `ea` | 1 |
| ``Units/Count/piece`` | `pc` | 1 |
| ``Units/Count/pair`` | `pair` | 2 |
| ``Units/Count/halfDozen`` | `half-doz` | 6 |
| ``Units/Count/dozen`` | `doz` | 12 |
| ``Units/Count/bakerDozen`` | `baker-doz` | 13 |
| ``Units/Count/score`` | `score` | 20 |
| ``Units/Count/gross`` | `gross` | 144 |
| ``Units/Count/greatGross`` | `great-gross` | 1,728 |
| ``Units/Count/hundred`` | `hundred` | 100 |
| ``Units/Count/thousand`` | `thousand` | 1,000 |
| ``Units/Count/million`` | `million` | 1,000,000 |

They are also available flat (``Units/dozen``) and through leading-dot lookup:

```swift
let eggs = Quantity(value: 2, unit: .dozen)
let each = eggs.converted(to: .each) // 24
```

## Encoding counts

``CountUnit`` is `Codable`, so counts survive a JSON round trip with their item
identity and scale intact:

```swift
let data = try JSONEncoder().encode(carton)
let decoded = try JSONDecoder().decode(Quantity<CountUnit>.self, from: data)

decoded.unit.item   // "egg"
decoded.unit.factor // 12
```

- SeeAlso: ``CountUnit``, ``Units/Count``, ``MathUnit/isCompatible(with:)``
