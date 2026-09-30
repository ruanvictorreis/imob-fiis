import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Backup contínuo da carteira")
struct PortfolioBackupTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func writesBackupOnlyWhenPositionsChange() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        #expect(try store.backUpIfNeeded([position("KNCR11", shares: 10)], now: start))
        #expect(try !store.backUpIfNeeded([position("KNCR11", shares: 10)], now: start.addingTimeInterval(7200)))

        let backup = try #require(store.latestBackupURL().flatMap(store.read))
        #expect(backup.positions == [position("KNCR11", shares: 10)])
        #expect(backup.createdAt == start)
    }

    @Test
    func updatesLatestBackupWithinMinimumInterval() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        try store.backUpIfNeeded([position("KNCR11", shares: 10)], now: start)
        try store.backUpIfNeeded([position("KNCR11", shares: 12)], now: start.addingTimeInterval(600))
        #expect(try backupCount(in: store) == 1)

        try store.backUpIfNeeded([position("KNCR11", shares: 15)], now: start.addingTimeInterval(7200))
        #expect(try backupCount(in: store) == 2)
        #expect(store.latestBackupURL().flatMap(store.read)?.positions.first?.shares == 15)
    }

    @Test
    func skipsEmptyPortfolioAndKeepsRecentBackupsOnly() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        #expect(try !store.backUpIfNeeded([PortfolioBackup.Position](), now: start))
        for day in 0 ..< PortfolioBackupStore.retainedBackups + 3 {
            let now = start.addingTimeInterval(TimeInterval(day) * 86_400)
            try store.backUpIfNeeded([position("KNCR11", shares: day + 1)], now: now)
        }

        #expect(try backupCount(in: store) == PortfolioBackupStore.retainedBackups)
    }

    @Test
    func keepsExactAveragePrice() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let price = try #require(Decimal(string: "98.37"))

        try store.backUpIfNeeded([position("KNCR11", shares: 10, averagePrice: price)], now: start)

        #expect(store.latestBackupURL().flatMap(store.read)?.positions.first?.averagePrice == price)
    }

    @Test @MainActor
    func recoveryRestoresPositionsFromLatestJSONBackup() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let updatedAt = start.addingTimeInterval(-3600)
        try store.backUpIfNeeded(
            [
                position("HGLG11", shares: 5, updatedAt: updatedAt),
                position("KNCR11", shares: 10, updatedAt: updatedAt),
            ],
            now: start
        )
        try Data("corrompido".utf8).write(to: store.directory.appending(path: Persistence.portfolioStoreName))

        #expect(try PersistenceRecovery.restoreFromBackup(in: store.directory, now: start))
        let persistence = try Persistence.loadAppPersistence(directory: store.directory, cloudKitDatabase: nil)

        let holdings = try persistence.container.mainContext.fetch(
            FetchDescriptor<Holding>(sortBy: [SortDescriptor(\.ticker)])
        )
        #expect(holdings.map(\.ticker) == ["HGLG11", "KNCR11"])
        #expect(holdings.map(\.shares) == [5, 10])
        #expect(holdings.allSatisfy { $0.updatedAt == updatedAt })
        let pending = store.directory.appending(path: PortfolioBackupStore.pendingRestoreName)
        #expect(!FileManager.default.fileExists(atPath: pending.path(percentEncoded: false)))
    }

    private func makeStore() throws -> PortfolioBackupStore {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PortfolioBackupTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return PortfolioBackupStore(directory: directory)
    }

    private func position(
        _ ticker: String,
        shares: Int,
        averagePrice: Decimal = 100,
        updatedAt: Date? = nil
    ) -> PortfolioBackup.Position {
        PortfolioBackup.Position(
            ticker: ticker,
            shares: shares,
            averagePrice: averagePrice,
            purchasedAt: start,
            updatedAt: updatedAt,
            notes: ""
        )
    }

    private func backupCount(in store: PortfolioBackupStore) throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: store.backupsDirectory.path(percentEncoded: false)).count
    }
}
