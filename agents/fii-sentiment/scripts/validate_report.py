#!/usr/bin/env python3
"""Validate a segment sentiment JSON file against the JSON Schema."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:
    print("Install dependencies: pip install -r agents/fii-sentiment/requirements.txt", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "schema" / "segment-report.schema.json"


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate FII sentiment report JSON")
    parser.add_argument("report", type=Path, help="Path to segment report JSON")
    args = parser.parse_args()

    if not args.report.is_file():
        print(f"Report not found: {args.report}", file=sys.stderr)
        sys.exit(1)

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    report = json.loads(args.report.read_text(encoding="utf-8"))

    try:
        jsonschema.validate(instance=report, schema=schema)
    except jsonschema.ValidationError as error:
        print(f"Validation failed: {error.message}", file=sys.stderr)
        sys.exit(1)

    print(f"Valid report: {args.report} ({len(report.get('funds', []))} funds)")


if __name__ == "__main__":
    main()
