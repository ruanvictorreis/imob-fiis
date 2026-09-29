import SwiftUI

struct FundNewsSection: View {
    let coverage: FundNewsCoverage
    let segment: FundSegment

    private static let maxHeadlines = 3
    private static let locale = Locale(identifier: "pt_BR")

    var body: some View {
        switch coverage {
        case .loading:
            EmptyView()
        case .covered(let sentiment, let generatedAt):
            coveredSection(sentiment, generatedAt: generatedAt)
        case .tickerNotCovered:
            unavailableSection(L10n.FundDetail.newsTickerNotCovered(segment.title))
        case .segmentNotCovered:
            unavailableSection(L10n.FundDetail.newsSegmentNotCovered(segment.title))
        case .unavailable:
            unavailableSection(L10n.FundDetail.newsLoadFailed)
        }
    }

    private func coveredSection(_ sentiment: FundSentiment, generatedAt: Date) -> some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                InsightSentimentBadge(label: sentiment.sentiment)
                Text(sentiment.summary)
                    .font(.subheadline)
                Text(metadataText(sentiment, generatedAt: generatedAt))
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
                if SentimentFreshness.isStale(generatedAt) {
                    Label(L10n.FundDetail.newsStale, systemImage: "clock.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }
            .padding(.vertical, Spacing.xxs)
            .accessibilityElement(children: .combine)

            ForEach(Array(sentiment.topHeadlines.prefix(Self.maxHeadlines).enumerated()), id: \.offset) { _, headline in
                headlineLink(headline)
            }
        } header: {
            Text(L10n.FundDetail.news)
        } footer: {
            Text(L10n.FundDetail.newsFooter)
        }
        .imobSurface()
    }

    private func unavailableSection(_ message: String) -> some View {
        Section(L10n.FundDetail.news) {
            Label(message, systemImage: "newspaper")
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)
                .padding(.vertical, Spacing.xxs)
        }
        .imobSurface()
    }

    private func headlineLink(_ headline: SentimentHeadline) -> some View {
        Link(destination: headline.url) {
            HStack(spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(headline.title)
                        .font(.subheadline)
                        .foregroundStyle(Color.appPrimaryText)
                        .multilineTextAlignment(.leading)
                    Text(caption(for: headline))
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }
                Spacer(minLength: Spacing.xs)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
                    .accessibilityHidden(true)
            }
        }
    }

    private func metadataText(_ sentiment: FundSentiment, generatedAt: Date) -> String {
        let articles = L10n.FundDetail.newsArticles(sentiment.articleCount)
        return "\(articles) · \(L10n.FundDetail.newsUpdated(Self.relativeText(generatedAt)))"
    }

    private func caption(for headline: SentimentHeadline) -> String {
        let source = headline.url.host()?.replacingOccurrences(of: "www.", with: "") ?? ""
        guard let date = Self.formattedDate(headline.publishedAt) else { return source }
        return source.isEmpty ? date : "\(source) · \(date)"
    }

    static func relativeText(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named).locale(locale))
    }

    static func formattedDate(_ publishedAt: String?) -> String? {
        guard let publishedAt, !publishedAt.isEmpty else { return nil }
        guard let date = try? Date(publishedAt, strategy: .iso8601.year().month().day()) else {
            return publishedAt
        }
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(locale)
        style.timeZone = .gmt
        return date.formatted(style)
    }
}
