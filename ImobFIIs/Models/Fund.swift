import Foundation
import SwiftData

enum FundSegment: String, Codable, CaseIterable, Identifiable {
    case logistics = "Logística"
    case offices = "Lajes Corporativas"
    case malls = "Shoppings"
    case paper = "Papel"
    case hybrid = "Híbrido"
    case fundsOfFunds = "Fundo de Fundos"
    case urban = "Renda Urbana"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .logistics: "shippingbox.fill"
        case .offices: "building.2.fill"
        case .malls: "bag.fill"
        case .paper: "doc.text.fill"
        case .hybrid: "square.split.2x1.fill"
        case .fundsOfFunds: "rectangle.stack.fill"
        case .urban: "storefront.fill"
        }
    }
}

@Model
final class Fund {
    #Unique<Fund>([\.ticker])

    var ticker: String
    var name: String
    var segmentRaw: String
    var manager: String
    var currentPrice: Decimal
    var dividendYield: Double
    var lastDividend: Decimal
    var vacancyRate: Double?

    @Relationship(deleteRule: .cascade, inverse: \Holding.fund)
    var holdings: [Holding] = []

    var segment: FundSegment {
        get { FundSegment(rawValue: segmentRaw) ?? .hybrid }
        set { segmentRaw = newValue.rawValue }
    }

    var isInPortfolio: Bool {
        !holdings.isEmpty
    }

    init(
        ticker: String,
        name: String,
        segment: FundSegment,
        manager: String,
        currentPrice: Decimal,
        dividendYield: Double,
        lastDividend: Decimal,
        vacancyRate: Double? = nil
    ) {
        self.ticker = ticker
        self.name = name
        self.segmentRaw = segment.rawValue
        self.manager = manager
        self.currentPrice = currentPrice
        self.dividendYield = dividendYield
        self.lastDividend = lastDividend
        self.vacancyRate = vacancyRate
    }
}
