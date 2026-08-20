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
    case residential = "Residencial"
    case fiagro = "Fiagro"
    case other = "Outros"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logistics: L10n.Segment.logistics
        case .offices: L10n.Segment.offices
        case .malls: L10n.Segment.malls
        case .paper: L10n.Segment.paper
        case .hybrid: L10n.Segment.hybrid
        case .fundsOfFunds: L10n.Segment.fundsOfFunds
        case .urban: L10n.Segment.urban
        case .residential: L10n.Segment.residential
        case .fiagro: L10n.Segment.fiagro
        case .other: L10n.Segment.other
        }
    }

    var systemImage: String {
        switch self {
        case .logistics: "shippingbox.fill"
        case .offices: "building.2.fill"
        case .malls: "bag.fill"
        case .paper: "doc.text.fill"
        case .hybrid: "square.split.2x1.fill"
        case .fundsOfFunds: "rectangle.stack.fill"
        case .urban: "storefront.fill"
        case .residential: "house.fill"
        case .fiagro: "leaf.fill"
        case .other: "building.columns.fill"
        }
    }

    static func fromAPI(subsector: String?, subType: String? = nil, name: String? = nil) -> FundSegment {
        if subType == "fi-agro" {
            return .fiagro
        }

        let fromSubsector = segment(forSubsector: subsector)
        if fromSubsector != .other {
            return fromSubsector
        }

        return inferred(from: name) ?? .other
    }

    private static func segment(forSubsector subsector: String?) -> FundSegment {
        let normalized = subsector?
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case "logistica":
            return .logistics
        case "lajes corporativas", "lages corporativas", "escritorios":
            return .offices
        case "shoppings":
            return .malls
        case "titulos e val. mob.", "titulos e valores mobiliarios", "papel":
            return .paper
        case "hibrido":
            return .hybrid
        case "fundo de fundos", "fof":
            return .fundsOfFunds
        case "renda urbana", "varejo":
            return .urban
        case "residencial":
            return .residential
        case "fiagro":
            return .fiagro
        default:
            return .other
        }
    }

    private static func inferred(from name: String?) -> FundSegment? {
        let blob = name?
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased() ?? ""
        guard !blob.isEmpty else { return nil }

        if containsAny(blob, ["fiagro", "agronegocio", "agroindustrial", "agricola", "rural", " agro"]) {
            return .fiagro
        }
        if containsAny(blob, ["fundo de fundos", "fofii"]) {
            return .fundsOfFunds
        }
        if containsAny(blob, ["securities", "recebiveis", "credito", " cri", "indice de papel"]) {
            return .paper
        }
        if containsAny(blob, ["renda urbana", "imoveis urbanos"]) {
            return .urban
        }
        if blob.contains("residencial") {
            return .residential
        }
        if blob.contains("logistica") {
            return .logistics
        }
        if blob.contains("shopping") {
            return .malls
        }
        if containsAny(blob, ["laje", "lage", "office", "escritorio", "edificios corporativos"]) {
            return .offices
        }
        return nil
    }

    private static func containsAny(_ blob: String, _ tokens: [String]) -> Bool {
        tokens.contains { blob.contains($0) }
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
    var lastDividendUpdatedAt: Date?
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
        lastDividendUpdatedAt: Date? = nil,
        vacancyRate: Double? = nil
    ) {
        self.ticker = ticker
        self.name = name
        self.segmentRaw = segment.rawValue
        self.manager = manager
        self.currentPrice = currentPrice
        self.dividendYield = dividendYield
        self.lastDividend = lastDividend
        self.lastDividendUpdatedAt = lastDividendUpdatedAt
        self.vacancyRate = vacancyRate
    }
}
