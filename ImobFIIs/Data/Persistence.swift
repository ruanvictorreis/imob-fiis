import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema(versionedSchema: SchemaV2.self)
    static let cloudKitContainerIdentifier = "iCloud.br.com.ruanvictorreis.Lumina"
    static let portfolioStoreName = "portfolio.store"
    static let marketCacheStoreName = "market-cache.store"
    static let legacyStoreName = "default.store"

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Container do app: carteira no CloudKit (banco privado) e cache de fundos local.
    /// Sem iCloud disponível (build sem assinatura) cai para armazenamento só local.
    /// Lança erro quando nem o store local abre, para o app oferecer a tela de recuperação.
    @MainActor
    static func loadAppPersistence(
        directory: URL = .applicationSupportDirectory,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase? = .private(cloudKitContainerIdentifier),
        fileManager: FileManager = .default
    ) throws -> AppPersistence {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let persistence: AppPersistence
        if let cloudKitDatabase,
           let container = try? makeContainerThrowing(directory: directory, cloudKitDatabase: cloudKitDatabase) {
            persistence = AppPersistence(container: container, isCloudSyncEnabled: true)
        } else {
            let container = try makeContainerThrowing(directory: directory)
            persistence = AppPersistence(container: container, isCloudSyncEnabled: false)
        }

        // Se falhar, o arquivo antigo permanece e a importação é tentada no próximo launch.
        _ = try? LegacyStoreImporter.importIfNeeded(
            from: directory.appending(path: legacyStoreName),
            into: persistence.container.mainContext,
            fileManager: fileManager
        )
        return persistence
    }

    /// Container em memória para previews e testes.
    static func makeContainer(inMemory: Bool = true) -> ModelContainer {
        do {
            return try makeContainerThrowing(inMemory: inMemory)
        } catch {
            preconditionFailure("Não foi possível criar o ModelContainer em memória: \(error)")
        }
    }

    static func makeContainerThrowing(
        inMemory: Bool = false,
        directory: URL? = nil,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none
    ) throws -> ModelContainer {
        let portfolioSchema = Schema([Holding.self])
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

struct AppPersistence {
    let container: ModelContainer
    let isCloudSyncEnabled: Bool
}
