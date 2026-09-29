import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema(versionedSchema: SchemaV1.self)

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) -> ModelContainer {
        do {
            return try makeContainerThrowing(inMemory: inMemory, url: url)
        } catch {
            fatalError("Não foi possível criar o ModelContainer: \(error)")
        }
    }

    static func makeContainerThrowing(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: ImobMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
