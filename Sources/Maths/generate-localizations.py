#!/usr/bin/env python3
"""Generate Resources/Localisable.xcstrings from the unit catalog.

Every `NamedUnit` and built-in `CountUnit` declaration carries a
`localizationKey`. This script scans the Swift sources and writes two catalog
entries per key:

    unit.name.<key>    human-readable unit name, e.g. "nautical mile"
    unit.symbol.<key>  display symbol, e.g. "NM"

The catalog is British English (`en-GB`), so names use UK spellings such as
"metre" and "litre". The canonical symbol in code is never localized. Only
`displaySymbol` and `name` read these entries, so equality, conversion, and
serialization stay locale-independent.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "Resources" / "Localisable.xcstrings"
TRANSLATIONS_FILE = ROOT / "unit-translations.json"
SOURCE_LANGUAGE = "en"
LANGUAGES = ("en", "en-GB", "fr", "de", "ru")

SI_PREFIXES = (
    "quetta", "ronna", "yotta", "zetta", "exa", "peta", "tera", "giga",
    "mega", "kilo", "hecto", "deca", "deci", "centi", "milli", "micro",
    "nano", "pico", "femto", "atto", "zepto", "yocto", "ronto", "quecto",
    "yobi", "zebi", "exbi", "pebi", "tebi", "gibi", "mebi", "kibi",
)

PREFIX_TRANSLATIONS = {
    "quetta": {"fr": "quetta", "de": "Quetta", "ru": "кветта"},
    "ronna": {"fr": "ronna", "de": "Ronna", "ru": "ронна"},
    "yotta": {"fr": "yotta", "de": "Yotta", "ru": "йотта"},
    "zetta": {"fr": "zetta", "de": "Zetta", "ru": "зетта"},
    "exa": {"fr": "exa", "de": "Exa", "ru": "экса"},
    "peta": {"fr": "péta", "de": "Peta", "ru": "пета"},
    "tera": {"fr": "téra", "de": "Tera", "ru": "тера"},
    "giga": {"fr": "giga", "de": "Giga", "ru": "гига"},
    "mega": {"fr": "méga", "de": "Mega", "ru": "мега"},
    "kilo": {"fr": "kilo", "de": "Kilo", "ru": "кило"},
    "hecto": {"fr": "hecto", "de": "Hekto", "ru": "гекто"},
    "deca": {"fr": "déca", "de": "Deka", "ru": "дека"},
    "deci": {"fr": "déci", "de": "Dezi", "ru": "деци"},
    "centi": {"fr": "centi", "de": "Zenti", "ru": "санти"},
    "milli": {"fr": "milli", "de": "Milli", "ru": "милли"},
    "micro": {"fr": "micro", "de": "Mikro", "ru": "микро"},
    "nano": {"fr": "nano", "de": "Nano", "ru": "нано"},
    "pico": {"fr": "pico", "de": "Piko", "ru": "пико"},
    "femto": {"fr": "femto", "de": "Femto", "ru": "фемто"},
    "atto": {"fr": "atto", "de": "Atto", "ru": "атто"},
    "zepto": {"fr": "zepto", "de": "Zepto", "ru": "зепто"},
    "yocto": {"fr": "yocto", "de": "Yokto", "ru": "йокто"},
    "ronto": {"fr": "ronto", "de": "Ronto", "ru": "ронто"},
    "quecto": {"fr": "quecto", "de": "Quekto", "ru": "квекто"},
    "yobi": {"fr": "yobi", "de": "Yobi", "ru": "йоби"},
    "zebi": {"fr": "zébi", "de": "Zebi", "ru": "зеби"},
    "exbi": {"fr": "exbi", "de": "Exbi", "ru": "эксби"},
    "pebi": {"fr": "pébi", "de": "Pebi", "ru": "пеби"},
    "tebi": {"fr": "tébi", "de": "Tebi", "ru": "теби"},
    "gibi": {"fr": "gibi", "de": "Gibi", "ru": "гиби"},
    "mebi": {"fr": "mébi", "de": "Mebi", "ru": "меби"},
    "kibi": {"fr": "kibi", "de": "Kibi", "ru": "киби"},
}

VOWELS = "aeiouyàâäéèêëîïôöùûüœæ"

NAMED_UNIT_RE = re.compile(
    r"^\s*(?:public\s+)?static\s+let\s+(`?[A-Za-z_][A-Za-z0-9_]*`?)\s*=\s*NamedUnit\s*<"
)
COUNT_UNIT_RE = re.compile(
    r"^\s*(?:public\s+)?static\s+let\s+(`?[A-Za-z_][A-Za-z0-9_]*`?)\s*=\s*CountUnit\s*\("
)
SYMBOL_RE = re.compile(r'symbol:\s*"((?:[^"\\]|\\.)*)"')
DIMENSION_RE = re.compile(r"dimension:\s*\.([A-Za-z_][A-Za-z0-9_]*)")
KEY_RE = re.compile(r'localizationKey:\s*"([^"]+)"')

SPECIAL_WORDS = {
    "us": "US",
    "uk": "UK",
    "tnt": "TNT",
    "planck": "Planck",
    "british": "British",
    "japanese": "Japanese",
    "celsius": "Celsius",
    "fahrenheit": "Fahrenheit",
    "btc": "BTC",
    "eth": "ETH",
}


def swift_string(raw: str) -> str:
    """Unescape the small subset of Swift string escapes used by unit symbols."""
    return raw.replace('\\"', '"').replace("\\\\", "\\")


def british_spelling(name: str) -> str:
    """Convert American unit spellings to the British English forms."""
    return (
        name.replace("meter", "metre")
        .replace("Meter", "Metre")
        .replace("liter", "litre")
        .replace("Liter", "Litre")
    )


def pretty_name(key: str, dimension: str, british: bool = True) -> str:
    """Turn a localization key into a readable unit name.

    With ``british=True`` (the ``en-GB`` catalog) the name uses British
    spellings such as "metre" and "litre". With ``british=False`` the key's own
    spelling is preserved, which gives the plain ``en`` catalog entries.
    """
    key = key.strip("`")

    if dimension == "currency":
        return key.upper()

    spaced = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", key)
    spaced = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", spaced)

    words = []
    for word in spaced.split():
        lowercased = word.lower()
        words.append(SPECIAL_WORDS.get(lowercased, lowercased))
    name = " ".join(words)
    return british_spelling(name) if british else name


def split_prefix(key: str, all_keys: set[str]) -> tuple[str | None, str]:
    """Split a generated key into its SI prefix and base key, if possible."""
    for prefix in SI_PREFIXES:
        if key.startswith(prefix) and key[len(prefix):] in all_keys:
            return prefix, key[len(prefix):]
    return None, key


def apply_prefix(prefix: str, base: str, language: str) -> str:
    """Attach a translated SI prefix to an already-translated base name."""
    translated_prefix = PREFIX_TRANSLATIONS[prefix][language]

    if language == "de":
        base = base[0].lower() + base[1:]
        separator = "-" if " " in base else ""
        combined = f"{translated_prefix}{separator}{base}"
        return combined[:1].upper() + combined[1:]

    base = base[0].lower() + base[1:]
    if language == "fr":
        if " " in base:
            return f"{translated_prefix}-{base}"
        ends_with_vowel = translated_prefix[-1].lower() in VOWELS
        starts_with_vowel = base[0].lower() in VOWELS
        separator = "-" if ends_with_vowel and starts_with_vowel else ""
        return f"{translated_prefix}{separator}{base}"

    # Russian
    separator = "-" if " " in base else ""
    return f"{translated_prefix}{separator}{base}"


def translated_name(
    key: str,
    dimension: str,
    language: str,
    all_keys: set[str],
    translations: dict,
) -> str:
    """Translate a unit key into French, German, or Russian."""
    if dimension == "currency":
        currency = translations["currency"].get(key)
        if currency:
            return currency[language]
        return key.upper()

    prefix, base = split_prefix(key, all_keys)
    if prefix is not None:
        return apply_prefix(
            prefix,
            translated_name(base, dimension, language, all_keys, translations),
            language,
        )

    translation = translations["base"].get(key)
    if translation:
        value = translation[language]
        if language == "de":
            value = value[:1].upper() + value[1:]
        return value

    # Unknown unit: keep the plain English name rather than leaving a gap.
    return pretty_name(key, dimension, british=False)


def matching_paren(text: str, opening: int) -> int:
    """Return the index of the `)` matching the `(` at `opening`."""
    depth = 0
    for index in range(opening, len(text)):
        character = text[index]
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"Unbalanced parentheses at offset {opening}")


def unit_declarations(path: Path):
    """Yield (identifier, symbol, dimension, localizationKey) for a source file."""
    text = path.read_text(encoding="utf-8")
    offset = 0

    for line in text.splitlines(keepends=True):
        stripped = line.lstrip()
        if stripped.startswith("//"):
            offset += len(line)
            continue

        match = NAMED_UNIT_RE.match(line)
        is_count = False
        if match:
            opening = text.find("(", offset + match.end())
        else:
            match = COUNT_UNIT_RE.match(line)
            is_count = True
            opening = offset + match.end() - 1 if match else -1

        if not match or opening == -1:
            offset += len(line)
            continue

        identifier = match.group(1).strip("`")
        closing = matching_paren(text, opening)
        block = text[opening : closing + 1]

        symbol_match = SYMBOL_RE.search(block)
        dimension_match = DIMENSION_RE.search(block)
        key_match = KEY_RE.search(block)

        if symbol_match:
            dimension = (
                dimension_match.group(1)
                if dimension_match
                else ("dimensionless" if is_count else "")
            )
            yield (
                identifier,
                swift_string(symbol_match.group(1)),
                dimension,
                key_match.group(1) if key_match else None,
            )

        offset += len(line)


def catalog_entry(values: dict[str, str]) -> dict:
    return {
        "extractionState": "manual",
        "localizations": {
            language: {
                "stringUnit": {
                    "state": "translated",
                    "value": values[language],
                }
            }
            for language in LANGUAGES
        },
    }


def main() -> None:
    translations = json.loads(TRANSLATIONS_FILE.read_text(encoding="utf-8"))
    entries: dict[str, tuple[str, str, str]] = {}
    missing_keys: list[str] = []

    for path in sorted((ROOT / "Models").glob("*.swift")):
        for identifier, symbol, dimension, key in unit_declarations(path):
            if key is None:
                missing_keys.append(f"{path.name}: {identifier}")
                continue

            name = pretty_name(key, dimension)
            existing = entries.get(key)
            if existing is not None and existing != (name, symbol, dimension):
                print(
                    f"warning: duplicate localization key {key!r}: "
                    f"{existing!r} vs {(name, symbol, dimension)!r}"
                )
                continue

            entries[key] = (name, symbol, dimension)

    all_keys = set(entries)
    strings: dict[str, dict] = {}
    for key, (name, symbol, dimension) in sorted(entries.items()):
        names = {
            "en": pretty_name(key, dimension, british=False),
            "en-GB": name,
        }
        for language in ("fr", "de", "ru"):
            names[language] = translated_name(
                key, dimension, language, all_keys, translations
            )

        strings[f"unit.name.{key}"] = catalog_entry(names)
        strings[f"unit.symbol.{key}"] = catalog_entry(
            {language: symbol for language in LANGUAGES}
        )

    catalog = {
        "sourceLanguage": SOURCE_LANGUAGE,
        "strings": strings,
        "version": "1.3",
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : "))
        + "\n",
        encoding="utf-8",
    )

    print(f"Generated {OUTPUT} with {len(entries)} localized units")

    if missing_keys:
        print(
            "warning: NamedUnit declarations without localizationKey "
            "(not added to the catalog):"
        )
        for missing in missing_keys:
            print(f"  {missing}")


if __name__ == "__main__":
    main()
