You are running in GitHub Actions for the Lumina (imob-fiis) repository.

Read and follow `agents/fii-sentiment/SKILL.md`.

Today's segment:
- segmentKey: {{SEGMENT_KEY}}
- segmentName: {{SEGMENT_NAME}}
- tickers file: agents/fii-sentiment/tickers/{{SEGMENT_KEY}}.json
- output file: docs/sentiment/{{SEGMENT_KEY}}.json

Tasks:
1. Read the tickers JSON for this segment.
2. Research recent FII news (last 7–14 days) on the allowed portals for each ticker.
3. Write a valid segment report JSON matching `agents/fii-sentiment/schema/segment-report.schema.json`.
4. Save ONLY to `docs/sentiment/{{SEGMENT_KEY}}.json`.

Do NOT modify Swift code, workflows, tests, or any file outside `docs/sentiment/{{SEGMENT_KEY}}.json`.

After writing, print a one-line summary: ticker count and output path.
