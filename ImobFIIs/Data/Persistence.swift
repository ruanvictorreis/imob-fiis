import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema(versionedSchema: SchemaV2.self)
    static let cloudKitContainerIdentifier = "iCloud.br.com.ruanvictorreis.Lumina"
    static let portfolioStoreName = "portfolio.store"
    static let marketCacheStoreName = "market-cache.store"
    static let legacyStoreName = "default.store"

    /// Container do app: carteira no CloudKit (banco privado) e cache de fundos local.
    /// Sem iCloud disponível (build sem assinatura, testes) cai para armazenamento só local.
    @MainActor
    static func makeAppContainer() -> ModelContainer {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return makeContainer(inMemory: true)
        }

        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let container: ModelContainer
        do {
            container = try makeContainerThrowing(
                directory: directory,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        } catch {
            container = makeContainer(directory: directory)
        }

        // Se falhar, o arquivo antigo permanece e a importação é tentada no próximo launch.
        _ = try? LegacyStoreImporter.importIfNeeded(
            from: directory.appending(path: legacyStoreName),
            into: container.mainContext
        )
        return container
    }

    static func makeContainer(inMemory: Bool = false, directory: URL? = nil) -> ModelContainer {
        do {
            return try makeContainerThrowing(inMemory: inMemory, directory: directory)
        } catch {
            fatalError("Não foi possível criar o ModelContainer: \(error)")
        }
    }

    static func makeContainerThrowing(
        inMemory: Bool = false,
        directory: URL? = nil,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none
    ) throws -> ModelContainer {
        let portfolioSchema = Schema([Holding.self, PortfolioTransaction.self])
        let marketCacheSchema = Schema([Fund.self])

        let configurations: [ModelConfiguration]
        if let directory, !inMemory {
            configurations = [
                ModelConfiguration(
                    "Portfolio",
                    schema: portfolioSchema,
                    url: directory.appending(path: portfolioStoreName),
                    cloudKitDatabase: cloudKitDatabase
                ),
                ModelConfiguration(
                    "MarketCache",
                    schema: marketCacheSchema,
                    url: directory.appending(path: marketCacheStoreName),
                    cloudKitDatabase: .none
                ),
            ]
        } else {
            configurations = [
                ModelConfiguration(
                    "Portfolio",
                    schema: portfolioSchema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
                ModelConfiguration(
                    "MarketCache",
                    schema: marketCacheSchema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: ImobMigrationPlan.self,
            configurations: configurations
        )
    }
}
