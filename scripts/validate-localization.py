#!/usr/bin/env python3
"""Check interface catalogs; optionally compare keys actually extracted by Swift.

Use xcodebuild SWIFT_EMIT_LOC_STRINGS=YES and pass its Objects-normal/<arch>
folder with --extracted. User transcripts never belong in these catalogs.
"""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PAIRS = re.compile(r'("(?:\\.|[^"\\])*") = ("(?:\\.|[^"\\])*");')
FORMATS = re.compile(r"%(?:[0-9]+\$)?(?:lld|ld|d|@)")
# Language-neutral labels, numeric-only formats and a deliberate vocabulary example.
NEUTRAL = {"%@ · %@", "%lld/%lld", "0.75×", "1×", "PDF", "SRT", "TXT", "VTT",
           "VoiceToRead", "VoiceToRead\nmeeting = reunión\nOpenAI", "…"}


def read_catalog(language, name):
    path = ROOT / "VoiceToRead/Resources" / f"{language}.lproj" / name
    rows = [(json.loads(key), json.loads(value)) for key, value in PAIRS.findall(path.read_text())]
    if not rows or len(rows) != len(dict(rows)):
        raise ValueError(f"Empty catalog or duplicate keys: {path}")
    return dict(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extracted", type=Path)
    args = parser.parse_args()
    for name in ("Localizable.strings", "InfoPlist.strings"):
        en, es = read_catalog("en", name), read_catalog("es", name)
        if en.keys() != es.keys():
            raise ValueError(f"Different English/Spanish keys in {name}")
        for key in en:
            placeholders = lambda value: sorted(FORMATS.findall(value))
            if not placeholders(key) == placeholders(en[key]) == placeholders(es[key]):
                raise ValueError(f"Changed interpolation placeholders: {key!r}")
        print(f"{name}: {len(en)} keys, matching languages and placeholders")
    if args.extracted:
        files = list(args.extracted.rglob("*.stringsdata"))
        if not files:
            raise ValueError("No compiler-generated .stringsdata files found")
        extracted = set()
        for path in files:
            obj = json.loads(path.read_text())
            extracted.update(item["key"] for item in obj.get("tables", {}).get("Localizable", []))
        missing = extracted - read_catalog("en", "Localizable.strings").keys() - NEUTRAL
        if missing:
            raise ValueError(f"Missing extracted keys: {sorted(missing)}")
        print(f"{len(extracted)} compiler-extracted keys covered (including language-neutral labels)")


if __name__ == "__main__":
    main()
