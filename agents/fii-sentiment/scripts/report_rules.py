"""Deterministic rules for segment sentiment reports, shared by normalize and validate."""

from __future__ import annotations

import json
import re
from datetime import date, datetime, timedelta
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
CLI_CONFIG_PATH = ROOT / "cli.json"

# Headlines dated up to one day after generatedAt are tolerated (time zones / late publishing).
FUTURE_TOLERANCE = timedelta(days=1)


def allowed_domains(config_path: Path = CLI_CONFIG_PATH) -> set[str]:
    """Portals the agent may fetch, read from the WebFetch allowlist in cli.json."""
    config = json.loads(config_path.read_text(encoding="utf-8"))
    domains = set()
    for permission in config.get("permissions", {}).get("allow", []):
        match = re.fullmatch(r"WebFetch\((.+)\)", permission)
        if match:
            domains.add(normalize_host(match.group(1)))
    return domains


def normalize_host(host: str) -> str:
    host = host.lower()
    return host[4:] if host.startswith("www.") else host


def expected_confidence(article_count: int) -> str:
    if article_count < 2:
        return "low"
    if article_count <= 4:
        return "medium"
    return "high"


def generated_date(report: dict) -> date:
    return datetime.fromisoformat(str(report["generatedAt"]).replace("Z", "+00:00")).date()


def window_start(report: dict) -> date:
    return generated_date(report) - timedelta(days=int(report["lookbackDays"]))


def parse_published(value: str) -> date | None:
    try:
        return date.fromisoformat(value)
    except (TypeError, ValueError):
        return None


def is_outside_window(headline: dict, report: dict) -> bool:
    """True only for valid dates older than the lookback window."""
    published = parse_published(headline.get("publishedAt", ""))
    return published is not None and published < window_start(report)


def normalize(report: dict) -> list[str]:
    """Apply deterministic fixes in place and return a description of each change."""
    changes: list[str] = []
    for fund in report.get("funds", []):
        ticker = fund.get("ticker", "?")

        headlines = fund.get("topHeadlines", [])
        kept = [headline for headline in headlines if not is_outside_window(headline, report)]
        if len(kept) != len(headlines):
            changes.append(f"{ticker}: removed {len(headlines) - len(kept)} headline(s) outside the lookback window")
            fund["topHeadlines"] = kept

        confidence = expected_confidence(int(fund.get("articleCount", 0)))
        if fund.get("confidence") != confidence:
            changes.append(f"{ticker}: confidence {fund.get('confidence')} -> {confidence}")
            fund["confidence"] = confidence

        if fund.get("articleCount") == 0 and fund.get("sentiment") == "neutral" and fund.get("score") != 0:
            changes.append(f"{ticker}: score {fund.get('score')} -> 0 (no articles)")
            fund["score"] = 0
    return changes


def semantic_errors(report: dict, domains: set[str]) -> list[str]:
    """Rules the JSON Schema can't express. Empty list means the report is valid."""
    errors: list[str] = []
    try:
        generated = generated_date(report)
    except (KeyError, ValueError):
        return [f"Invalid generatedAt: {report.get('generatedAt')!r}"]
    start = window_start(report)

    for fund in report.get("funds", []):
        ticker = fund.get("ticker", "?")
        article_count = int(fund.get("articleCount", 0))

        if fund.get("confidence") != expected_confidence(article_count):
            errors.append(
                f"{ticker}: confidence {fund.get('confidence')} does not match articleCount {article_count}"
            )
        if article_count == 0:
            if fund.get("sentiment") != "neutral" or fund.get("score") != 0:
                errors.append(f"{ticker}: no articles must be neutral with score 0")
            if fund.get("topHeadlines"):
                errors.append(f"{ticker}: no articles must not list headlines")

        for headline in fund.get("topHeadlines", []):
            url = headline.get("url", "")
            host = normalize_host(urlparse(url).hostname or "")
            if host not in domains:
                errors.append(f"{ticker}: headline from non-allowed domain: {url}")

            raw_date = headline.get("publishedAt")
            if raw_date is None:
                continue
            published = parse_published(raw_date)
            if published is None:
                errors.append(f"{ticker}: invalid publishedAt {raw_date!r}")
            elif published > generated + FUTURE_TOLERANCE:
                errors.append(f"{ticker}: publishedAt {raw_date} is after generatedAt")
            elif published < start:
                errors.append(f"{ticker}: publishedAt {raw_date} is outside the lookback window")
    return errors
