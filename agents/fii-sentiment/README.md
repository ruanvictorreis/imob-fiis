# FII Sentiment Agent

Pipeline diário que usa o **Cursor CLI** para pesquisar notícias de FIIs e publicar JSON em GitHub Pages.

## Setup

1. Configure o secret no repositório:
   ```bash
   gh secret set CURSOR_API_KEY --repo ruanvictorreis/imob-fiis
   ```
2. Habilite **GitHub Pages** em Settings → Pages → Deploy from branch `main`, folder `/docs`.

## Rodízio de segmentos (UTC)

| Dia | Segmento |
|-----|----------|
| Seg | Papel |
| Ter | Renda Urbana |
| Qua | Logística |
| Qui | Shoppings |
| Sex | Lajes Corporativas |
| Sáb | Fiagro |
| Dom | Manifest (validação) |

## Execução manual

Actions → **FII Sentiment Daily** → Run workflow → escolha o segmento.

## Validação local

```bash
pip install -r agents/fii-sentiment/requirements.txt
python agents/fii-sentiment/scripts/validate_report.py docs/sentiment/paper.json
python agents/fii-sentiment/scripts/merge_manifest.py
```

## Saída

- `docs/sentiment/{segmentKey}.json` — relatório por segmento
- `docs/sentiment/manifest.json` — índice
- URL: `https://ruanvictorreis.github.io/imob-fiis/sentiment/`
