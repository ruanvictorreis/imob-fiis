import SwiftUI

struct FundNewsSection: View {
    let sentiment: FundSentiment
    let generatedAt: Date?

    private static let maxHeadlines = 3
    private static let locale = Locale(identifier: "pt_BR")

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                InsightSentimentBadge(label: sentiment.sentiment)
                Text(sentiment.summary)
                    .font(.subheadline)
                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
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

    private var metadataText: String {
        let articles = L10n.FundDetail.newsArticles(sentiment.articleCount)
        guard let generatedAt else { return articles }
        let relative = generatedAt.formatted(.relative(presentation: .named).locale(Self.locale))
        return "\(articles) · \(L10n.FundDetail.newsUpdated(relative))"
    }

    private func caption(for headline: SentimentHeadline) -> String {
        let source = headline.url.host()?.replacingOccurrences(of: "www.", with: "") ?? ""
        guard let date = Self.formattedDate(headline.publishedAt) else { return source }
        return source.isEmpty ? date : "\(source) · \(date)"
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
