# Backlog do Lumina

Atualizado em 1º de outubro de 2026. Prioridades:

- **P0:** bloqueia o TestFlight.
- **P1:** antes de abrir o TestFlight externo ou publicar na App Store.
- **P2:** evolução do produto.

## 1. Preparação para o TestFlight

### P0: obrigatório antes do primeiro upload

| # | Item | Por quê | Esforço |
|---|------|---------|---------|
| T1 | Fazer o deploy do schema do CloudKit para **Production** no CloudKit Console | Builds do TestFlight usam o ambiente de produção. Sem o schema, a sincronização da carteira falha para os testadores | P |
| T2 | Adicionar `PrivacyInfo.xcprivacy` com o motivo de uso de `UserDefaults` (CA92.1) e "nenhum dado coletado" | O app usa `UserDefaults` (metas, sincronização de preços, notícias). Sem o manifesto, o upload gera o aviso ITMS-91053 | P |
| T3 | Adicionar `ITSAppUsesNonExemptEncryption = NO` no `Info.plist` | O app só usa HTTPS. Evita responder ao questionário de exportação a cada build | P |
| T4 | Confirmar que o arquivamento de Release lê o token da brapi em `Config/Secrets.xcconfig` | Sem token, as cotações caem direto no Yahoo e no cache | P |
| T5 | Aumentar `CURRENT_PROJECT_VERSION` a cada upload; manter a versão `1.0` | O App Store Connect rejeita builds com número repetido | P |
| T6 | Testar a sincronização com uma conta iCloud diferente, num build de Release em aparelho físico | O ambiente de produção do CloudKit só é exercitado nesse tipo de build | M |
| T7 | Conferir o `aps-environment` no build arquivado (tem que ser `production`) | O arquivo `Lumina.entitlements` está com `development`; a assinatura automática costuma trocar, mas vale confirmar | P |

### P1: antes do TestFlight externo (revisão da Apple)

| # | Item | Por quê | Esforço |
|---|------|---------|---------|
| T8 | Publicar uma política de privacidade (uma página simples) | Exigida no App Store Connect, inclusive para teste externo | P |
| T9 | Preencher os rótulos de privacidade da loja ("nenhum dado coletado") | Diferencial real do app: sem conta e sem servidor | P |
| T10 | Escrever o texto "O que testar" e o e-mail de contato para feedback | Orienta os testadores e agiliza a revisão do teste externo | P |
| T11 | Revisar os textos dos Insights para a linguagem analítica, sem recomendação de compra (Resolução CVM 20) | Evita configurar recomendação de investimento | P |
| T12 | Consultar a marca "Lumina" no INPI (classes 9 e 36) | "Lumina" é um nome bastante usado em apps | P |

## 2. Melhorias técnicas

| # | Prioridade | Item | Detalhe |
|---|-----------|------|---------|
| E1 | P1 | **Proxy para a brapi** | Hoje o token vai dentro do binário e todos os usuários dividem a mesma cota. Um Cloudflare Worker (ou Firebase Function) guarda o token e mantém as cotações em cache por alguns minutos |
| E2 | P1 | **Rever o fallback do Yahoo** | Os termos do Yahoo Finance restringem uso comercial. Usar só como último recurso ou trocar por uma fonte licenciada |
| E3 | P1 | **Logs com `os.Logger`** | Na sincronização com o iCloud, no backup e na restauração, e na recuperação do banco. Essencial para diagnosticar problemas dos testadores |
| E4 | P1 | **Crash reporting** | Os relatórios de travamento do TestFlight e do Xcode Organizer já bastam no início; avaliar o Crashlytics depois |
| E5 | P2 | **Testes de interface do fluxo principal** | Adicionar posição, editar, ver Insights, simular aporte e adicionar cotas pelo segmento |
| E6 | P2 | **Analytics que respeite a privacidade** | TelemetryDeck ou só o App Analytics da Apple, para medir retenção e uso das telas |
| E7 | P2 | **Dividir arquivos grandes** | `AddHoldingSheet` e `FundDetailView` se aproximam do limite de 400 linhas do SwiftLint |

## 3. Produto

| # | Prioridade | Item | Detalhe |
|---|-----------|------|---------|
| F1 | P1 | **Nome e textos da loja** | Nome "Lumina: Carteira de FIIs", subtítulo com palavras-chave ("Metas, proventos e rebalanceio"), capturas de tela e descrição |
| F2 | P2 | **Proventos por mês** | Registrar os dividendos recebidos e mostrar um gráfico da renda mensal, sem depender do histórico de transações |
| F3 | P2 | **Widget** | Patrimônio e renda mensal estimada na tela inicial |
| F4 | P2 | **Notificações** | Data-com e pagamento de proventos dos fundos da carteira, e mudança de sentimento das notícias |
| F5 | P2 | **Simulador por fundo** | Dividir o aporte sugerido do segmento entre os FIIs que você já tem, como evolução da tela de segmento do PR #37 |
| F6 | P2 | **Ampliar a cobertura de notícias** | Híbrido, Fundo de Fundos e Residencial ainda não têm relatório |
| F7 | P2 | **Atalho para fundos sem cobertura** | Sugerir no Explorar fundos do mesmo segmento que têm análise |
| F8 | P2 | **Exportar a carteira** | Salvar CSV ou JSON no app Arquivos, reaproveitando o formato do backup contínuo |
| F9 | P2 | **Ícone com referência a imóveis** | O cristal lembra cripto; um detalhe arquitetônico sutil reforçaria o tema |

## 4. Monetização (depois do TestFlight)

| # | Item | Detalhe |
|---|------|---------|
| M1 | Lançar grátis, sem anúncios | Colher avaliações e medir retenção (E6) |
| M2 | Recompensar os primeiros usuários | Guardar a `originalAppVersion` (StoreKit 2, `AppTransaction`) para dar Pro vitalício ou desconto a quem entrou na fase gratuita |
| M3 | Assinatura Pro com StoreKit 2 | Pro com alertas, widgets, proventos e projeções, e calculadora de aporte por fundo. A carteira básica continua grátis |
| M4 | Inscrição no App Store Small Business Program | Comissão de 15% em vez de 30% |
| M5 | Resolver o licenciamento dos dados antes de cobrar | Depende de E1 e E2 |

## Já entregue

| PR | Entrega |
|----|---------|
| #27, #31 | Sincronização da carteira pelo CloudKit e remoção de posições duplicadas |
| #32 | Metas de alocação sincronizadas pelo iCloud, indicador de sincronização e tela de recuperação |
| #33 | Animação do indicador de sincronização; saiu o "Atualizado às" |
| #34 | Backup contínuo, cache dos Insights e cotações com fallback no Yahoo e cache local |
| #35 | Alocação "Carteira padrão", textos justificados, ajustes de espaçamento |
| #36 | Novo ícone (Icon Composer) e splash escura; correção de travamento em builds sem assinatura |
| #37 | Simular aporte com navegação por segmento e detalhes do FII (em revisão) |

## Ordem sugerida até o TestFlight

1. Fazer o merge do PR #37.
2. Resolver T1–T7: um PR curto com o manifesto de privacidade, o `Info.plist` e o número do build, mais as configurações no CloudKit Console.
3. Adicionar os logs (E3), para ter diagnóstico já na primeira rodada de testes.
4. Arquivar, enviar e abrir o TestFlight interno.
5. Em paralelo ao teste interno: política de privacidade, textos da loja e revisão da linguagem dos Insights (T8–T12, F1).
6. Abrir o TestFlight externo.
