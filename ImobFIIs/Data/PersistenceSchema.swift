import Foundation
import SwiftData

/// Versão 1: formato dos dados publicado até a introdução do versionamento.
///
/// Ao alterar `Fund` ou `Holding`, congele esta versão antes: copie as definições atuais
/// dos modelos para dentro deste enum (`SchemaV1.Fund`, `SchemaV1.Holding`), crie um
/// `SchemaV2` apontando para os modelos novos e adicione a etapa em `ImobMigrationPlan`.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Fund.self, Holding.self]
    }
}

enum ImobMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
