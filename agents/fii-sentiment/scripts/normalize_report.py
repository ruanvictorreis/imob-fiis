#!/usr/bin/env python3
"""Apply deterministic fixes to segment sentiment reports before validation."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from report_rules import normalize


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize FII sentiment report JSON in place")
    parser.add_argument("reports", type=Path, nargs="+", help="Paths to segment report JSON files")
    args = parser.parse_args()

    for path in args.reports:
        report = json.loads(path.read_text(encoding="utf-8"))
        changes = normalize(report)
        if not changes:
            print(f"{path}: no changes")
            continue
        path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"{path}: {len(changes)} change(s)")
        for change in changes:
            print(f"  - {change}")


if __name__ == "__main__":
    main()
