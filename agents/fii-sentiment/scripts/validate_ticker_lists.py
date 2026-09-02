#!/usr/bin/env python3
"""Ensure exclusive tickers appear in exactly one segment list."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TICKERS_DIR = ROOT / "tickers"
EXCLUSIVE_PATH = TICKERS_DIR / "exclusive.json"


def load_segment_tickers() -> dict[str, set[str]]:
    segments: dict[str, set[str]] = {}
    for path in sorted(TICKERS_DIR.glob("*.json")):
        if path.name == "exclusive.json":
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        key = data.get("segmentKey") or path.stem
        segments[key] = {ticker.upper() for ticker in data.get("tickers", [])}
    return segments


def main() -> None:
    if not EXCLUSIVE_PATH.is_file():
        print(f"Missing exclusive ticker map: {EXCLUSIVE_PATH}", file=sys.stderr)
        sys.exit(1)

    exclusive = json.loads(EXCLUSIVE_PATH.read_text(encoding="utf-8")).get("assignments", {})
    segments = load_segment_tickers()
    errors: list[str] = []

    for ticker, canonical_segment in exclusive.items():
        normalized = ticker.upper()
        canonical = canonical_segment.lower()
        present_in = [key for key, tickers in segments.items() if normalized in tickers]

        if present_in == [canonical]:
            continue
        if not present_in:
            errors.append(f"{normalized} must appear in '{canonical}' but is missing from all lists")
        elif canonical not in present_in:
            errors.append(
                f"{normalized} must appear in '{canonical}' but only found in: {', '.join(sorted(present_in))}"
            )
        else:
            extra = [key for key in present_in if key != canonical]
            errors.append(
                f"{normalized} must appear only in '{canonical}' but also listed in: {', '.join(sorted(extra))}"
            )

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    print(f"Exclusive ticker lists OK ({len(exclusive)} assignments)")


if __name__ == "__main__":
    main()
