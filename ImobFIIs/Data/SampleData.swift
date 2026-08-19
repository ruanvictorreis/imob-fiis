import Foundation
import SwiftData

enum SampleData {
    static let catalogCount = 12

    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<Fund>()
        descriptor.fetchLimit = 1

        let hasFunds = (try? context.fetch(descriptor).isEmpty == false) ?? false
        guard !hasFunds else { return }

        for fund in makeCatalog() {
            context.insert(fund)
        }

        try? context.save()
    }

    static func makeCatalog() -> [Fund] {
        [
            Fund(
                ticker: "HGLG11",
                name: "CSHG Logística",
                segment: .logistics,
                manager: "Credit Suisse Hedging-Griffo",
                currentPrice: 1_632.40,
                dividendYield: 0.084,
                lastDividend: 11.00,
                vacancyRate: 0.03
            ),
            Fund(
                ticker: "BTLG11",
                name: "BTG Pactual Logística",
                segment: .logistics,
                manager: "BTG Pactual",
                currentPrice: 102.85,
                dividendYield: 0.091,
                lastDividend: 0.78,
                vacancyRate: 0.02
            ),
            Fund(
                ticker: "XPLG11",
                name: "XP Log",
                segment: .logistics,
                manager: "XP Asset",
                currentPrice: 98.12,
                dividendYield: 0.088,
                lastDividend: 0.72,
                vacancyRate: 0.04
            ),
            Fund(
                ticker: "HGRE11",
                name: "CSHG Real Estate",
                segment: .offices,
                manager: "Credit Suisse Hedging-Griffo",
                currentPrice: 118.40,
                dividendYield: 0.079,
                lastDividend: 0.78,
                vacancyRate: 0.11
            ),
            Fund(
                ticker: "PVBI11",
                name: "VBI Prime Properties",
                segment: .offices,
                manager: "VBI Real Estate",
                currentPrice: 84.50,
                dividendYield: 0.082,
                lastDividend: 0.58,
                vacancyRate: 0.08
            ),
            Fund(
                ticker: "XPML11",
                name: "XP Malls",
                segment: .malls,
                manager: "XP Asset",
                currentPrice: 104.20,
                dividendYield: 0.095,
                lastDividend: 0.82,
                vacancyRate: 0.05
            ),
            Fund(
                ticker: "VISC11",
                name: "Vinci Shopping Centers",
                segment: .malls,
                manager: "Vinci Partners",
                currentPrice: 112.75,
                dividendYield: 0.092,
                lastDividend: 0.86,
                vacancyRate: 0.04
            ),
            Fund(
                ticker: "MXRF11",
                name: "Maxi Renda",
                segment: .paper,
                manager: "XP Asset",
                currentPrice: 9.92,
                dividendYield: 0.128,
                lastDividend: 0.10
            ),
            Fund(
                ticker: "KNCR11",
                name: "Kinea Rendimentos Imobiliários",
                segment: .paper,
                manager: "Kinea Investimentos",
                currentPrice: 104.80,
                dividendYield: 0.121,
                lastDividend: 1.05
            ),
            Fund(
                ticker: "KNRI11",
                name: "Kinea Renda Imobiliária",
                segment: .hybrid,
                manager: "Kinea Investimentos",
                currentPrice: 142.30,
                dividendYield: 0.086,
                lastDividend: 1.02,
                vacancyRate: 0.06
            ),
            Fund(
                ticker: "HFOF11",
                name: "Hedge Top FOFII 3",
                segment: .fundsOfFunds,
                manager: "Hedge Investments",
                currentPrice: 76.40,
                dividendYield: 0.102,
                lastDividend: 0.65
            ),
            Fund(
                ticker: "HGRU11",
                name: "CSHG Renda Urbana",
                segment: .urban,
                manager: "Credit Suisse Hedging-Griffo",
                currentPrice: 124.90,
                dividendYield: 0.089,
                lastDividend: 0.92,
                vacancyRate: 0.01
            ),
        ]
    }
}
