#!/usr/bin/env python3
"""Build docs/sentiment/manifest.json from segment report files."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

SEGMENT_KEYS = ("paper", "urban", "logistics", "malls", "offices", "fiagro")


def main() -> None:
    parser = argparse.ArgumentParser(description="Merge sentiment segment reports into manifest.json")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("docs/sentiment"),
        help="Directory containing segment JSON files",
    )
    args = parser.parse_args()

    output_dir = args.output_dir
    segments: dict[str, dict] = {}
    latest: datetime | None = None

    for key in SEGMENT_KEYS:
        path = output_dir / f"{key}.json"
        if not path.is_file():
            continue
        report = json.loads(path.read_text(encoding="utf-8"))
        generated_at = report.get("generatedAt", "")
        segments[key] = {
            "updatedAt": generated_at,
            "fundCount": len(report.get("funds", [])),
            "url": f"{key}.json",
        }
        try:
            parsed = datetime.fromisoformat(generated_at.replace("Z", "+00:00"))
            if latest is None or parsed > latest:
                latest = parsed
        except ValueError:
            pass

    manifest = {
        "version": 1,
        "updatedAt": (latest or datetime.now(timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "segments": segments,
    }

    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {manifest_path} ({len(segments)} segments)")


if __name__ == "__main__":
    main()
