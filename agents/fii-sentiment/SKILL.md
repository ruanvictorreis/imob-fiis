# FII Sentiment Agent

Analisa notícias recentes de fundos imobiliários brasileiros e gera um relatório JSON de sentimento por segmento.

## Quando usar

- Workflow diário do GitHub Actions (`fii-sentiment-daily.yml`)
- Segmento do dia definido em `SEGMENT_KEY` / `SEGMENT_NAME`

## Portais (prioridade)

1. https://www.clube.fii
2. https://www.fundsexplorer.com.br
3. https://statusinvest.com.br
4. https://www.suno.com.br
5. https://www.infomoney.com.br
6. https://fiis.com.br
7. https://www.moneytimes.com.br

Use WebFetch nesses domínios. Janela de notícias: **7–14 dias**.

## Tickers-alvo

Leia `agents/fii-sentiment/tickers/{segmentKey}.json`. Analise **todos** os tickers listados — e **somente** esses tickers.

Tickers exclusivos de um segmento (ex.: `TRXF11` → `urban`) estão em `agents/fii-sentiment/tickers/exclusive.json`. Não inclua esses tickers em outros segmentos.

## Classificação por FII

Para cada ticker:

| Campo | Regra |
|-------|-------|
| `sentiment` | `positive`, `neutral` ou `negative` |
| `score` | `-1.0` … `1.0` (negativo = pessimista) |
| `confidence` | `low` (<2 fontes), `medium` (2–4), `high` (5+) |
| `summary` | 1–2 frases em pt-BR, factual. Atribua recomendação de terceiros à instituição. Não diga que o leitor deve comprar ou vender |
| `articleCount` | notícias consideradas |
| `topHeadlines` | até 3: `title`, `url`, `publishedAt` (ISO date) |

## Saída

Escreva **somente** em `docs/sentiment/{segmentKey}.json`. Não altere código Swift, workflows ou outros arquivos.

Schema: `agents/fii-sentiment/schema/segment-report.schema.json`

## Metadados obrigatórios

- `version`: 1
- `segment`: nome legível (ex. "Papel")
- `segmentKey`: chave (ex. "paper")
- `generatedAt`: ISO 8601 UTC
- `lookbackDays`: 14
- `sources`: domínios consultados

## Critérios de sentimento

- **Positivo**: dividendos, ocupação, aquisições, guidance favorável
- **Neutro**: notícias administrativas ou mix equilibrado
- **Negativo**: vacância, inadimplência, corte de provento, risco regulatório

Se não houver notícias para um ticker, use `neutral`, `score: 0`, `confidence: low`, `articleCount: 0`, `topHeadlines: []` e `summary` explicando ausência de cobertura.

## Validação automática

Depois que você escreve o arquivo, o workflow roda `normalize_report.py` e `validate_report.py` (regras em `scripts/report_rules.py`):

- **Corrigido automaticamente:** manchetes com `publishedAt` anterior a `generatedAt − lookbackDays` são removidas; `confidence` é recalculada a partir de `articleCount`; `score` vira 0 em fundos neutros sem notícias.
- **Reprova o relatório:** manchete de domínio fora da lista de portais; `publishedAt` inválido (use `AAAA-MM-DD`) ou mais de 1 dia depois de `generatedAt`; fundo com `articleCount: 0` que não seja neutro com score 0 ou que liste manchetes.

Por isso, cite em `topHeadlines` apenas notícias dentro da janela e de portais permitidos.
