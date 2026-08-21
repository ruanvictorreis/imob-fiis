import Foundation

enum L10n {
    enum App {
        static var name: String { text("app.name") }
    }

    enum Common {
        static var dash: String { text("common.dash") }
        static var close: String { text("common.close") }
        static var ok: String { text("common.ok") }
        static var notSpecified: String { text("common.notSpecified") }
        static var all: String { text("common.all") }
        static var retry: String { text("common.retry") }
        static var delete: String { text("common.delete") }
        static var add: String { text("common.add") }
        static var save: String { text("common.save") }
        static var ticker: String { text("common.ticker") }
        static var name: String { text("common.name") }
        static var segment: String { text("common.segment") }
        static var select: String { text("common.select") }
    }

    enum Tab {
        static var portfolio: String { text("tab.portfolio") }
        static var explore: String { text("tab.explore") }
        static var insights: String { text("tab.insights") }
    }

    enum Portfolio {
        static var title: String { text("portfolio.title") }
        static var positions: String { text("portfolio.positions") }
        static var addShares: String { text("portfolio.addShares") }
        static var editPosition: String { text("portfolio.editPosition") }
        static var netWorth: String { text("portfolio.netWorth") }
        static var invested: String { text("portfolio.invested") }
        static var result: String { text("portfolio.result") }
        static var emptyTitle: String { text("portfolio.emptyTitle") }
        static var emptyDescription: String { text("portfolio.emptyDescription") }
        static var addFund: String { text("portfolio.addFund") }
    }

    enum Accessory {
        static var estimatedIncome: String { text("accessory.estimatedIncome") }
        static var estimatedIncomeFormula: String { text("accessory.estimatedIncomeFormula") }

        static func estimatedIncomeAccessibility(_ amount: String) -> String {
            format("accessory.estimatedIncomeAccessibility", amount)
        }
    }

    enum Holding {
        static func sharesAverage(shares: Int, average: String) -> String {
            format("holding.sharesAverage", shares, average)
        }
    }

    enum Explore {
        static var title: String { text("explore.title") }
        static var searchPrompt: String { text("explore.searchPrompt") }
        static var segmentFilter: String { text("explore.segmentFilter") }
        static var loading: String { text("explore.loading") }
        static var loadError: String { text("explore.loadError") }

        static func fundsCount(_ count: Int) -> String {
            format("explore.fundsCount", count)
        }
    }

    enum FundDetail {
        static var quote: String { text("fundDetail.quote") }
        static var currentPrice: String { text("fundDetail.currentPrice") }
        static var change: String { text("fundDetail.change") }
        static var previousClose: String { text("fundDetail.previousClose") }
        static var dayRange: String { text("fundDetail.dayRange") }
        static var weekRange: String { text("fundDetail.weekRange") }
        static var volume: String { text("fundDetail.volume") }
        static var indicators: String { text("fundDetail.indicators") }
        static var lastDividend: String { text("fundDetail.lastDividend") }
        static var dividendYield12m: String { text("fundDetail.dividendYield12m") }
        static var priceToNav: String { text("fundDetail.priceToNav") }
        static var nav: String { text("fundDetail.nav") }
        static var investors: String { text("fundDetail.investors") }
        static var vacancy: String { text("fundDetail.vacancy") }
        static var about: String { text("fundDetail.about") }
        static var management: String { text("fundDetail.management") }
        static var administrator: String { text("fundDetail.administrator") }
        static var addShares: String { text("fundDetail.addShares") }
        static var addToPortfolio: String { text("fundDetail.addToPortfolio") }
        static var editPosition: String { text("fundDetail.editPosition") }

        static func rangeValue(low: String, high: String) -> String {
            format("fundDetail.rangeValue", low, high)
        }
    }

    enum AddHolding {
        static var fund: String { text("addHolding.fund") }
        static var currentPosition: String { text("addHolding.currentPosition") }
        static var thisPurchase: String { text("addHolding.thisPurchase") }
        static var position: String { text("addHolding.position") }
        static var sharesThisPurchase: String { text("addHolding.sharesThisPurchase") }
        static var shares: String { text("addHolding.shares") }
        static var priceThisPurchase: String { text("addHolding.priceThisPurchase") }
        static var averagePrice: String { text("addHolding.averagePrice") }
        static var addSharesTitle: String { text("addHolding.addSharesTitle") }
        static var addToPortfolioTitle: String { text("addHolding.addToPortfolioTitle") }
        static var shareShortcuts: String { text("addHolding.shareShortcuts") }
        static var emptyFunds: String { text("addHolding.emptyFunds") }

        static func currentPositionValue(shares: Int, average: String) -> String {
            format("addHolding.currentPositionValue", shares, average)
        }

        static func projectedPosition(shares: Int, average: String) -> String {
            format("addHolding.projectedPosition", shares, average)
        }
    }

    enum EditHolding {
        static var title: String { text("editHolding.title") }
        static var helper: String { text("editHolding.helper") }
        static var tapToEdit: String { text("editHolding.tapToEdit") }
    }

    enum Insights {
        static var title: String { text("insights.title") }
        static var balancedStrategy: String { text("insights.balancedStrategy") }
        static var customStrategy: String { text("insights.customStrategy") }
        static var allocation: String { text("insights.allocation") }
        static var editAllocation: String { text("insights.editAllocation") }
        static var editAllocationTitle: String { text("insights.editAllocationTitle") }
        static var editAllocationHeader: String { text("insights.editAllocationHeader") }
        static var resetAllocation: String { text("insights.resetAllocation") }
        static var nextContribution: String { text("insights.nextContribution") }
        static var otherOptions: String { text("insights.otherOptions") }
        static var emptyTitle: String { text("insights.emptyTitle") }
        static var emptyDescription: String { text("insights.emptyDescription") }
        static var noMatchTitle: String { text("insights.noMatchTitle") }
        static var noMatchDescription: String { text("insights.noMatchDescription") }
        static var disclaimer: String { text("insights.disclaimer") }
        static var lowestWeightInSegment: String { text("insights.lowestWeightInSegment") }
        static var belowAveragePrice: String { text("insights.belowAveragePrice") }
        static var nextPurchaseYield: String { text("insights.nextPurchaseYield") }

        static func target(_ percent: String) -> String {
            format("insights.target", percent)
        }

        static func segmentGap(segment: String, current: String, target: String) -> String {
            format("insights.segmentGap", segment, current, target)
        }

        static func suggestedContribution(_ amount: String) -> String {
            format("insights.suggestedContribution", amount)
        }

        static func allocationTotalValid(_ percent: String) -> String {
            format("insights.allocationTotalValid", percent)
        }

        static func allocationTotalInvalid(_ percent: String) -> String {
            format("insights.allocationTotalInvalid", percent)
        }
    }

    enum Segment {
        static var logistics: String { text("segment.logistics") }
        static var offices: String { text("segment.offices") }
        static var malls: String { text("segment.malls") }
        static var paper: String { text("segment.paper") }
        static var hybrid: String { text("segment.hybrid") }
        static var fundsOfFunds: String { text("segment.fundsOfFunds") }
        static var urban: String { text("segment.urban") }
        static var residential: String { text("segment.residential") }
        static var fiagro: String { text("segment.fiagro") }
        static var other: String { text("segment.other") }
    }

    fileprivate static func text(_ key: String) -> String {
        String(localized: LocalizedStringResource(stringLiteral: key))
    }

    fileprivate static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: .current, arguments: arguments)
    }
}
