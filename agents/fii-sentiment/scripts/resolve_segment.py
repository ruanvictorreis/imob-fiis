#!/usr/bin/env python3
"""Resolve segment key from weekday or manual override."""

from __future__ import annotations

import argparse
import os
from datetime import datetime, timezone

SEGMENTS_BY_WEEKDAY = {
    0: "paper",      # Monday
    1: "urban",      # Tuesday
    2: "logistics",  # Wednesday
    3: "malls",      # Thursday
    4: "offices",    # Friday
    5: "fiagro",     # Saturday
    6: "manifest",   # Sunday
}

SEGMENT_NAMES = {
    "paper": "Papel",
    "urban": "Renda Urbana",
    "logistics": "Logística",
    "malls": "Shoppings",
    "offices": "Lajes Corporativas",
    "fiagro": "Fiagro",
    "manifest": "Manifest",
}


def resolve_segment_key(manual: str | None = None, now: datetime | None = None) -> str:
    if manual:
        key = manual.strip().lower()
        if key not in SEGMENT_NAMES:
            valid = ", ".join(sorted(k for k in SEGMENT_NAMES if k != "manifest"))
            raise SystemExit(f"Invalid segment '{manual}'. Valid: {valid}, manifest")
        return key
    current = now or datetime.now(timezone.utc)
    return SEGMENTS_BY_WEEKDAY[current.weekday()]


def main() -> None:
    parser = argparse.ArgumentParser(description="Resolve FII sentiment segment for today")
    parser.add_argument("--segment", help="Manual segment key override")
    parser.add_argument("--github-output", action="store_true", help="Write GITHUB_OUTPUT pairs")
    args = parser.parse_args()

    segment_key = resolve_segment_key(args.segment)
    segment_name = SEGMENT_NAMES[segment_key]

    print(f"segment_key={segment_key}")
    print(f"segment_name={segment_name}")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if args.github_output and github_output:
        with open(github_output, "a", encoding="utf-8") as handle:
            handle.write(f"segment_key={segment_key}\n")
            handle.write(f"segment_name={segment_name}\n")


if __name__ == "__main__":
    main()
