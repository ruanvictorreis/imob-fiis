import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Posições duplicadas")
struct HoldingDeduplicatorTests {
    private let start = Date(timeIntervalSince1970: 1_780_000_000)

    @Test @MainActor
    func keepsMostRecentlyUpdatedHolding() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(Holding(ticker: "KNCR11", shares: 10, averagePrice: 98, updatedAt: start))
        context.insert(Holding(ticker: "KNCR11", shares: 15, averagePrice: 97, updatedAt: start.addingTimeInterval(60)))
        context.insert(Holding(ticker: "HGLG11", shares: 5, averagePrice: 160, updatedAt: start))

        #expect(HoldingDeduplicator.removeDuplicates(in: context) == 1)

        let holdings = try context.fetch(FetchDescriptor<Holding>(sortBy: [SortDescriptor(\.ticker)]))
        #expect(holdings.map(\.ticker) == ["HGLG11", "KNCR11"])
        #expect(holdings.last?.shares == 15)
    }

    @Test
    func prefersHoldingWithUpdateDateThenLaterPurchase() {
        let legacy = Holding(ticker: "KNCR11", shares: 10, averagePrice: 98, purchasedAt: start, updatedAt: nil)
        let edited = Holding(ticker: "KNCR11", shares: 12, averagePrice: 98, purchasedAt: start, updatedAt: start)
        #expect(HoldingDeduplicator.isMoreRecent(edited, legacy))

        let older = Holding(ticker: "KNCR11", shares: 10, averagePrice: 98, purchasedAt: start, updatedAt: nil)
        let newer = Holding(
            ticker: "KNCR11",
            shares: 12,
            averagePrice: 98,
            purchasedAt: start.addingTimeInterval(60),
            updatedAt: nil
        )
        #expect(HoldingDeduplicator.isMoreRecent(newer, older))
    }

    @Test
    func editingPositionUpdatesModificationDate() {
        let holding = Holding(ticker: "KNCR11", shares: 10, averagePrice: 100, updatedAt: nil)
        let now = start.addingTimeInterval(3_600)

        holding.addShares(10, at: 120, now: now)
        #expect(holding.updatedAt == now)

        let later = now.addingTimeInterval(60)
        holding.replacePosition(shares: 5, averagePrice: 90, now: later)
        #expect(holding.updatedAt == later)
    }

    @Test @MainActor
    func opensStoresCreatedBeforeUpdateDateAndRemovesDuplicates() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "HoldingDeduplicatorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try copyFixture("v2-portfolio", to: directory.appending(path: Persistence.portfolioStoreName))
        try copyFixture("v2-market-cache", to: directory.appending(path: Persistence.marketCacheStoreName))

        let container = try Persistence.makeContainerThrowing(directory: directory)
        let context = container.mainContext
        #expect(try context.fetch(FetchDescriptor<Holding>()).allSatisfy { $0.updatedAt == nil })

        HoldingDeduplicator.removeDuplicates(in: context)

        let holding = try #require(context.fetch(FetchDescriptor<Holding>()).first)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 1)
        #expect(holding.shares == 12)
        #expect(holding.fund?.ticker == "KNCR11")
    }

    private func copyFixture(_ name: String, to destination: URL) throws {
        let bundle = Bundle(for: DeduplicatorBundleToken.self)
        let source = try #require(bundle.url(forResource: name, withExtension: "store"))
        try FileManager.default.copyItem(at: source, to: destination)
    }
}

private final class DeduplicatorBundleToken {}
