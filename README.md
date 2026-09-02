# ImobFIIs

App iOS para acompanhar carteira de **FIIs e Fiagros**, explorar fundos e receber sugestões de aporte com base em alocação por segmento e sentimento de notícias recentes.

## Funcionalidades

### Carteira
- Cadastro de posições (cotas e preço médio)
- Atualização de cota via Yahoo Finance, com fallback para cotações da [brapi.dev](https://brapi.dev)
- Sincronização de último provento e classificação de segmento

### Explorar
- Catálogo de FIIs/Fiagros ativos
- Busca e filtro por segmento (Logística, Papel, Shoppings, Fiagro, etc.)
- Detalhes do fundo com indicadores

### Insights
- Metas de alocação por segmento (editáveis)
- Ranking de candidatos a próximo aporte com base em:
  - gap de segmento vs meta
  - menor peso dentro do segmento
  - preço abaixo da média
  - dividend yield
  - **sentimento** de notícias (badge + resumo)
- Bloqueio do top pick quando o sentimento é fortemente negativo (com confiança média/alta)

### Sentimento (automático)
Relatórios JSON publicados diariamente via GitHub Actions + Cursor CLI e consumidos pelo app com cache local de 24h.

URL base: `https://ruanvictorreis.github.io/imob-fiis/sentiment/`

Detalhes do pipeline: [`agents/fii-sentiment/README.md`](agents/fii-sentiment/README.md)

## Stack

| Camada | Tecnologia |
|--------|------------|
| UI | SwiftUI |
| Persistência | SwiftData |
| Rede | URLSession |
| Dados de mercado | Yahoo Finance, brapi.dev |
| Sentimento | JSON estático (GitHub Pages) |
| CI | GitHub Actions (SwiftLint + xcodebuild test) |

## Requisitos

- macOS com **Xcode 26.2** (ou compatível com o scheme do projeto)
- Simulador iOS 17+
- Token da brapi.dev (opcional, mas recomendado para catálogo e fallback de cotações)

## Configuração local

```bash
git clone https://github.com/ruanvictorreis/imob-fiis.git
cd imob-fiis
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Edite `Config/Secrets.xcconfig` e defina sua chave:

```
BRAPI_API_TOKEN = sua_chave_brapi
```

Abra `ImobFIIs.xcodeproj` no Xcode e rode no simulador (**⌘R**).

> `Config/Secrets.xcconfig` está no `.gitignore` — nunca commite tokens.

### Variáveis opcionais

| Chave | Onde | Uso |
|-------|------|-----|
| `BRAPI_API_TOKEN` | `Secrets.xcconfig` | Catálogo e cotações via brapi |
| `SENTIMENT_BASE_URL` | `Info.plist` | URL dos relatórios de sentimento (já aponta para GitHub Pages) |

## Testes

```bash
# SwiftLint (mesmo comando do CI)
swiftlint lint --strict

# Unit tests
xcodebuild test \
  -scheme ImobFIIs \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

## Estrutura do repositório

```
ImobFIIs/              App SwiftUI + SwiftData
ImobFIIsTests/         Testes unitários
agents/fii-sentiment/  Agente de sentimento (Cursor CLI + scripts Python)
docs/sentiment/        Relatórios JSON publicados no GitHub Pages
.github/workflows/     CI, sentimento diário e deploy de Pages
Config/                xcconfig compartilhado e secrets locais
```

## Workflows (GitHub Actions)

| Workflow | Trigger | Função |
|----------|---------|--------|
| **CI** | Pull request | SwiftLint + testes |
| **FII Sentiment Daily** | Cron + manual | Gera relatórios de sentimento por segmento |
| **GitHub Pages** | Push em `docs/**` | Publica JSONs de sentimento |

### Secrets necessários (Actions)

| Secret | Workflow |
|--------|----------|
| `CURSOR_API_KEY` | FII Sentiment Daily |

## Contribuindo

1. Crie um branch a partir de `main`
2. Garanta que `swiftlint lint --strict` e os testes passam
3. Abra um pull request

## Aviso

Este app é uma ferramenta pessoal de apoio à decisão. Não constitui recomendação de investimento.
