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

        if blob.contains("fiagro")
            || blob.contains("agronegocio")
            || blob.contains("agroindustrial")
            || blob.contains("agricola")
            || blob.contains("rural")
            || blob.contains(" agro")
        {
            return .fiagro
        }
        if blob.contains("fundo de fundos") || blob.contains("fofii") {
            return .fundsOfFunds
        }
        if blob.contains("securities")
            || blob.contains("recebiveis")
            || blob.contains("credito")
            || blob.contains(" cri")
            || blob.contains("indice de papel")
        {
            return .paper
        }
        if blob.contains("renda urbana") || blob.contains("imoveis urbanos") {
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
        if blob.contains("laje") || blob.contains("lage") || blob.contains("office")
            || blob.contains("escritorio") || blob.contains("edificios corporativos")
        {
            return .offices
        }
        return nil
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
