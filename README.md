# Math

> Type-safe dimensional analysis and unit conversion for Swift.

**Math** (the `Maths` Swift package) lets you work with physical quantities —
length, time, mass, energy, currency, and more — without ever mixing up your
dimensions. Instead of juggling raw numbers and hoping the physics lines up, you
model values as a [`Quantity`](Sources/Maths/Math.docc/Math.md): a `Decimal`
paired with a unit. The compiler rejects dimension mismatches *when you build*,
not when your app is running.

```swift
import Math

// Create a quantity with a value and a unit.
let marathon = Quantity(value: 42.195, unit: Units.kilometer)

// Convert it to another unit of the same dimension.
let inMiles = marathon.converted(to: Units.mile)

// Combine quantities and let the framework derive the result's dimension.
let speed = Quantity(value: 42.195, unit: Units.kilometer)
          / Quantity(value: 3, unit: Units.hour)

print(marathon) // 42.20 km
print(speed)    // 14.07 (km/h)
```

## Features

- **Compile-time dimension safety** — units carry their dimension in the type
  system, so passing a `time` where a `length` is expected is a compile error.
- **Exact arithmetic** — values are stored as `Decimal`, so base‑10 math (money,
  constants, repeated conversions) stays exact.
- **Hundreds of units** — 195 base units across 30 dimensions, expanding to
  thousands of SI-prefixed variants: from Planck lengths and parsecs to
  teaspoons, slugs, and bitcoin.
- **Typed ratios** — `RatioUnit` remembers which side of a fraction each unit is
  on, so `USD/kg` is a different type from `kg/USD`.
- **Type erasure** — `AnyQuantity`, `AnyMathUnit`, and `AnyDimension` for
  heterogeneous collections and runtime-only dimensions.
- **Persistence** — `Codable` and `Hashable` support JSON round‑trips and use as
  dictionary keys or set members.
- **Extensible** — define your own dimensions, units, and converters at runtime.
- **Localized & aviation‑ready** — unit names, symbols, and number spelling in
  five languages, plus ICAO/NATO radio pronunciation (see below).

## Requirements

- Swift 6.0+
- macOS 10.15+, iOS 13+, tvOS 13+, watchOS 6+, Mac Catalyst 13+

## Installation

Add **Math** through Swift Package Manager, or in Xcode use
**File → Add Package Dependencies…**:

```swift
// swift-tools-version: 6.0

let package = Package(
    name: "YourApp",
    dependencies: [
        .package(url: "https://github.com/PinkQween/Math-Units", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: ["Math"]
        )
    ]
)
```

Then `import Math` in your source files.

## Quick start

```swift
import Math

// Convert anything to anything (within the same dimension).
let chipFeature = Quantity(value: 5.0, unit: Units.nanometer)
print(chipFeature.converted(to: Units.metre).value) // 5e-09

// Arithmetic combines dimensions automatically.
let area = Quantity(value: 3.0, unit: Units.metre)
         * Quantity(value: 2.0, unit: Units.metre)
print(area.unit.dimension) // area

// Format for display.
let price = Quantity(value: 10.1234, unit: Units.usd)
print(price.formatted()) // $10.12

// Request the most readable unit for a result.
let ride = Quantity(value: 3600, unit: Units.second)
print(ride.simplified()) // 1 hour
```

## Language support

**Math** is fully localizable and can even spell numbers out as words.

- **Localized units** — every unit's display name and symbol are resolved through
  a string catalog (12,000+ entries), so "mile" becomes the right word and
  symbol for the active locale.
- **Languages** — English (US), English (UK — the default), French, German, and
  Russian.
- **Number spelling** — `NumberSpeller` writes numbers as words, localized to the
  same five languages, with short‑scale numbering for English and Russian and
  long‑scale numbering for French and German.

```swift
NumberSpeller.spelledOut(Decimal(string: "23")!) // "twenty-three"
NumberSpeller.spelledOut(Decimal(string: "45")!, locale: Locale(identifier: "ru_RU"))
// "сорок пять"
```

## Aviation support

Flight‑oriented apps get first‑class conveniences out of the box:

- **ICAO/NATO radio pronunciation** — `NumberSpellingStyle.aviation` spells digit
  words the way they're spoken over the radio (`nine` → "niner", `five` →
  "fife").
- **Aviation units** — nautical miles (`NM`), knots (`kt`), feet, and the full
  SI-prefixed nautical-mile family are ready to use and convert correctly.

```swift
NumberSpeller.spelledOut(Decimal(string: "9")!, style: .aviation) // "niner"

let airspeed = Quantity(value: 250, unit: Units.knot)
let cruise   = airspeed.converted(to: Units.metersPerSecond)
```

## Documentation

The full documentation is published to
[pinkqween.github.io/Math-Units](https://pinkqween.github.io/Math-Units/) and
kept up to date automatically by a GitHub Actions workflow on every push to
`main`.

To build and preview it locally with DocC:

```sh
swift package generate-documentation --target Maths
```

## License

Distributed under the Math-Units license — see [LICENSE](LICENSE). In short:

- You may use the software **as-is** in commercial, closed-source products
  without publishing your own source code.
- Any **changes** you distribute must also be made public, **unless** the
  copyright holder grants written permission to keep those changes private.
