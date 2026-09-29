import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Migração do SwiftData")
struct PersistenceMigrationTests {
    @Test @MainActor
    func opensStoreCreatedBeforeVersioning() throws {
        let url = try makeStoreURL()
        defer { removeStore(at: url) }

        do {
            let legacySchema = Schema([Fund.self, Holding.self])
            let legacy = try ModelContainer(
                for: legacySchema,
                configurations: [ModelConfiguration(schema: legacySchema, url: url)]
            )
            insertSamplePosition(in: legacy.mainContext)
            try legacy.mainContext.save()
        }

        let container = try Persistence.makeContainerThrowing(url: url)
        try expectSamplePosition(in: container.mainContext)
    }

    @Test @MainActor
    func keepsDataAcrossReopenWithMigrationPlan() throws {
        let url = try makeStoreURL()
        defer { removeStore(at: url) }

        do {
            let container = try Persistence.makeContainerThrowing(url: url)
            insertSamplePosition(in: container.mainContext)
            try container.mainContext.save()
        }

        let reopened = try Persistence.makeContainerThrowing(url: url)
        try expectSamplePosition(in: reopened.mainContext)
    }

    @Test
    func containerUsesLatestSchemaInMigrationPlan() {
        #expect(ImobMigrationPlan.schemas.last?.versionIdentifier == Persistence.schema.version)
    }

    @MainActor
    private func insertSamplePosition(in context: ModelContext) {
        let fund = Fund(
            ticker: "KNCR11",
            name: "Kinea Rendimentos",
            segment: .paper,
            manager: "Kinea",
            currentPrice: 102,
            dividendYield: 0.12,
            lastDividend: 1
        )
        context.insert(fund)
        context.insert(Holding(shares: 10, averagePrice: 98, fund: fund))
    }

    @MainActor
    private func expectSamplePosition(in context: ModelContext) throws {
        let holdings = try context.fetch(FetchDescriptor<Holding>())
        #expect(holdings.count == 1)
        #expect(holdings.first?.shares == 10)
        #expect(holdings.first?.averagePrice == 98)
        #expect(holdings.first?.fund?.ticker == "KNCR11")
        #expect(holdings.first?.fund?.segment == .paper)
    }

    private func makeStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistenceMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("default.store")
    }

    private func removeStore(at url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
