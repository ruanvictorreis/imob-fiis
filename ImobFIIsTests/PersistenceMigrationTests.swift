import Foundation
import SQLite3
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Migração do SwiftData")
struct PersistenceMigrationTests {
    @Test(arguments: ["legacy-unversioned", "legacy-versioned"]) @MainActor
    func importsLegacyStoreIntoSplitStores(fixture: String) throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = try copyFixture(fixture, to: directory)

        do {
            let container = try Persistence.makeContainerThrowing(directory: directory)
            #expect(try LegacyStoreImporter.importIfNeeded(from: legacyURL, into: container.mainContext))
        }

        let reopened = try Persistence.makeContainerThrowing(directory: directory)
        try expectFixturePortfolio(in: reopened.mainContext)
    }

    @Test @MainActor
    func movesLegacyStoreToBackupAfterImport() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = try copyFixture("legacy-versioned", to: directory)
        let container = try Persistence.makeContainerThrowing(directory: directory)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        try LegacyStoreImporter.importIfNeeded(from: legacyURL, into: container.mainContext, now: now)

        let backup = directory
            .appending(path: LegacyStoreImporter.backupDirectoryName)
            .appending(path: "1800000000")
            .appending(path: Persistence.legacyStoreName)
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: backup.path(percentEncoded: false)))
        #expect(try !LegacyStoreImporter.importIfNeeded(from: legacyURL, into: container.mainContext))
    }

    @Test @MainActor
    func legacyImportDoesNotDuplicateExistingPositions() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = try copyFixture("legacy-versioned", to: directory)
        let container = try Persistence.makeContainerThrowing(directory: directory)
        let context = container.mainContext
        context.insert(Holding(ticker: "KNCR11", shares: 3, averagePrice: 100))
        try context.save()

        try LegacyStoreImporter.importStore(at: legacyURL, into: context)
        try LegacyStoreImporter.importStore(at: legacyURL, into: context)

        let holdings = try context.fetch(FetchDescriptor<Holding>(sortBy: [SortDescriptor(\.ticker)]))
        #expect(holdings.map(\.ticker) == ["HGLG11", "KNCR11"])
        #expect(holdings.last?.shares == 3)
        #expect(try context.fetchCount(FetchDescriptor<Fund>()) == 3)
    }

    @Test @MainActor
    func keepsPortfolioAndMarketCacheInSeparateStores() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            let container = try Persistence.makeContainerThrowing(directory: directory)
            let fund = Fund(
                ticker: "KNCR11",
                name: "Kinea Rendimentos",
                segment: .paper,
                manager: "Kinea",
                currentPrice: 102,
                dividendYield: 0.12,
                lastDividend: 1
            )
            container.mainContext.insert(fund)
            container.mainContext.insert(Holding(shares: 10, averagePrice: 98, fund: fund))
            try container.mainContext.save()
        }

        let portfolio = directory.appending(path: Persistence.portfolioStoreName)
        let marketCache = directory.appending(path: Persistence.marketCacheStoreName)
        #expect(tableRowCount("ZHOLDING", in: portfolio) == 1)
        #expect(tableRowCount("ZFUND", in: marketCache) == 1)
        #expect((tableRowCount("ZFUND", in: portfolio) ?? 0) == 0)

        let reopened = try Persistence.makeContainerThrowing(directory: directory)
        let holding = try #require(reopened.mainContext.fetch(FetchDescriptor<Holding>()).first)
        #expect(holding.fund?.segment == .paper)
        #expect(holding.currentValue == 1020)
    }

    @Test
    func containerUsesLatestSchemaInMigrationPlan() {
        #expect(ImobMigrationPlan.schemas.last?.versionIdentifier == Persistence.schema.version)
    }

    @MainActor
    private func expectFixturePortfolio(in context: ModelContext) throws {
        let holdings = try context.fetch(FetchDescriptor<Holding>(sortBy: [SortDescriptor(\.ticker)]))
        #expect(holdings.map(\.ticker) == ["HGLG11", "KNCR11"])
        #expect(holdings.map(\.shares) == [5, 10])
        #expect(holdings.first?.averagePrice == Decimal(string: "155.40"))
        #expect(holdings.last?.notes == "Primeira compra")
        #expect(holdings.last?.purchasedAt == Date(timeIntervalSince1970: 1_780_000_000))
        #expect(holdings.first?.fund?.segment == .logistics)
        #expect(holdings.first?.fund?.vacancyRate == 0.05)

        let funds = try context.fetch(FetchDescriptor<Fund>(sortBy: [SortDescriptor(\.ticker)]))
        #expect(funds.map(\.ticker) == ["HGLG11", "KNCR11", "XPML11"])
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PersistenceMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func copyFixture(_ name: String, to directory: URL) throws -> URL {
        let source = try #require(Bundle(for: FixtureBundleToken.self).url(forResource: name, withExtension: "store"))
        let destination = directory.appending(path: Persistence.legacyStoreName)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    private func tableRowCount(_ table: String, in storeURL: URL) -> Int? {
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        guard sqlite3_open_v2(storeURL.path(percentEncoded: false), &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK
        else { return nil }

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM \(table)", -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW
        else { return nil }
        return Int(sqlite3_column_int64(statement, 0))
    }
}

private final class FixtureBundleToken {}
