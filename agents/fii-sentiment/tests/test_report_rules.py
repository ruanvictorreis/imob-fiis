import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from report_rules import allowed_domains, expected_confidence, normalize, semantic_errors  # noqa: E402

DOMAINS = {"fiis.com.br", "suno.com.br"}


def make_report(**fund_overrides):
    fund = {
        "ticker": "KNCR11",
        "sentiment": "positive",
        "score": 0.5,
        "confidence": "medium",
        "summary": "Resumo.",
        "articleCount": 3,
        "topHeadlines": [
            {"title": "Recente", "url": "https://www.fiis.com.br/a", "publishedAt": "2026-09-25"},
        ],
    }
    fund.update(fund_overrides)
    return {
        "version": 1,
        "segment": "Papel",
        "segmentKey": "paper",
        "generatedAt": "2026-09-28T18:45:00Z",
        "lookbackDays": 14,
        "sources": ["fiis.com.br"],
        "funds": [fund],
    }


class ExpectedConfidenceTests(unittest.TestCase):
    def test_thresholds(self):
        self.assertEqual([expected_confidence(n) for n in (0, 1, 2, 4, 5, 9)],
                         ["low", "low", "medium", "medium", "high", "high"])


class NormalizeTests(unittest.TestCase):
    def test_removes_headlines_outside_window_and_keeps_undated(self):
        report = make_report(topHeadlines=[
            {"title": "Antiga", "url": "https://fiis.com.br/old", "publishedAt": "2026-09-13"},
            {"title": "Limite", "url": "https://fiis.com.br/edge", "publishedAt": "2026-09-14"},
            {"title": "Sem data", "url": "https://fiis.com.br/nodate"},
        ])

        changes = normalize(report)

        titles = [headline["title"] for headline in report["funds"][0]["topHeadlines"]]
        self.assertEqual(titles, ["Limite", "Sem data"])
        self.assertEqual(len(changes), 1)

    def test_recomputes_confidence_from_article_count(self):
        report = make_report(articleCount=4, confidence="high")

        normalize(report)

        self.assertEqual(report["funds"][0]["confidence"], "medium")

    def test_zeroes_score_for_neutral_fund_without_articles(self):
        report = make_report(sentiment="neutral", score=-0.05, confidence="low", articleCount=0, topHeadlines=[])

        normalize(report)

        self.assertEqual(report["funds"][0]["score"], 0)

    def test_keeps_non_neutral_fund_without_articles_for_validation(self):
        report = make_report(sentiment="negative", score=-0.3, confidence="low", articleCount=0, topHeadlines=[])

        normalize(report)

        self.assertEqual(report["funds"][0]["score"], -0.3)

    def test_is_idempotent(self):
        report = make_report(articleCount=4, confidence="high")
        normalize(report)
        snapshot = copy.deepcopy(report)

        self.assertEqual(normalize(report), [])
        self.assertEqual(report, snapshot)


class SemanticErrorsTests(unittest.TestCase):
    def test_valid_report_has_no_errors(self):
        self.assertEqual(semantic_errors(make_report(), DOMAINS), [])

    def test_rejects_non_allowed_domain(self):
        report = make_report(topHeadlines=[
            {"title": "X", "url": "https://example.com/x", "publishedAt": "2026-09-25"},
        ])

        self.assertIn("non-allowed domain", semantic_errors(report, DOMAINS)[0])

    def test_rejects_future_and_invalid_dates(self):
        report = make_report(topHeadlines=[
            {"title": "Futuro", "url": "https://fiis.com.br/f", "publishedAt": "2026-10-05"},
            {"title": "Inválida", "url": "https://fiis.com.br/i", "publishedAt": "25/09/2026"},
        ])

        errors = semantic_errors(report, DOMAINS)

        self.assertEqual(len(errors), 2)
        self.assertIn("after generatedAt", errors[0])
        self.assertIn("invalid publishedAt", errors[1])

    def test_tolerates_headline_one_day_after_generation(self):
        report = make_report(topHeadlines=[
            {"title": "Amanhã", "url": "https://fiis.com.br/t", "publishedAt": "2026-09-29"},
        ])

        self.assertEqual(semantic_errors(report, DOMAINS), [])

    def test_rejects_non_neutral_fund_without_articles(self):
        report = make_report(sentiment="negative", score=-0.3, confidence="low", articleCount=0, topHeadlines=[])

        self.assertIn("neutral with score 0", semantic_errors(report, DOMAINS)[0])

    def test_rejects_confidence_mismatch(self):
        report = make_report(articleCount=1, confidence="medium")

        self.assertIn("does not match articleCount", semantic_errors(report, DOMAINS)[0])


class AllowedDomainsTests(unittest.TestCase):
    def test_reads_webfetch_allowlist_without_www(self):
        domains = allowed_domains()

        self.assertIn("fiis.com.br", domains)
        self.assertIn("statusinvest.com.br", domains)
        self.assertFalse(any(domain.startswith("www.") for domain in domains))


if __name__ == "__main__":
    unittest.main()
