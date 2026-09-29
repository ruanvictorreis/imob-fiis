import Foundation
import SwiftData

/// Versão 2: carteira (`Holding`, sincronizada via CloudKit) separada do cache local de fundos.
///
/// A versão 1 era um banco único local (`default.store`) com `Holding` apontando para `Fund`;
/// ela é lida pelo `LegacyStoreImporter`, não por uma etapa de migração.
///
/// O schema de produção do CloudKit só aceita mudanças aditivas: novos atributos precisam
/// ser opcionais ou ter valor padrão, e nada pode ser renomeado ou removido.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Fund.self, Holding.self]
    }
}

enum ImobMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
