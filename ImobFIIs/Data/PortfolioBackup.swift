import Foundation
import SwiftData

struct PortfolioBackup: Codable, Equatable {
    struct Position: Codable, Equatable {
        var ticker: String
        var shares: Int
        var averagePrice: Decimal
        var purchasedAt: Date
        var updatedAt: Date?
        var notes: String

        private enum CodingKeys: String, CodingKey {
            case ticker, shares, averagePrice, purchasedAt, updatedAt, notes
        }

        init(ticker: String, shares: Int, averagePrice: Decimal, purchasedAt: Date, updatedAt: Date?, notes: String) {
            self.ticker = ticker
            self.shares = shares
            self.averagePrice = averagePrice
            self.purchasedAt = purchasedAt
            self.updatedAt = updatedAt
            self.notes = notes
        }

        /// `Decimal` como texto: o `JSONDecoder` passa números por `Double` e perderia centavos.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawPrice = try container.decode(String.self, forKey: .averagePrice)
            guard let averagePrice = Decimal(string: rawPrice, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .averagePrice,
                    in: container,
                    debugDescription: "Preço médio inválido: \(rawPrice)"
                )
            }
            self.init(
                ticker: try container.decode(String.self, forKey: .ticker),
                shares: try container.decode(Int.self, forKey: .shares),
                averagePrice: averagePrice,
                purchasedAt: try container.decode(Date.self, forKey: .purchasedAt),
                updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt),
                notes: try container.decode(String.self, forKey: .notes)
            )
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ticker, forKey: .ticker)
            try container.encode(shares, forKey: .shares)
            try container.encode(averagePrice.description, forKey: .averagePrice)
            try container.encode(purchasedAt, forKey: .purchasedAt)
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
            try container.encode(notes, forKey: .notes)
        }
    }

    static let currentVersion = 1

    var version = currentVersion
    var createdAt: Date
    var positions: [Position]
}

extension PortfolioBackup.Position {
    init(_ holding: Holding) {
        self.init(
            ticker: holding.ticker,
            shares: holding.shares,
            averagePrice: holding.averagePrice,
            purchasedAt: holding.purchasedAt,
            updatedAt: holding.updatedAt,
            notes: holding.notes
        )
    }
}

/// Cópias em JSON da carteira em `Application Support/Backups/`, fora dos arquivos do SwiftData,
/// para a tela de recuperação ter o que restaurar mesmo sem iCloud.
struct PortfolioBackupStore {
    static let directoryName = "Backups"
    static let pendingRestoreName = "pending-restore.json"
    static let filePrefix = "portfolio-"

    /// Alterações dentro deste intervalo atualizam a cópia mais recente em vez de criar outra.
    static let minimumInterval: TimeInterval = 60 * 60
    static let retainedBackups = 14

    let directory: URL
    var fileManager: FileManager = .default

    var backupsDirectory: URL {
        directory.appending(path: Self.directoryName)
    }

    /// Grava uma cópia quando as posições mudaram desde a última. Carteira vazia não é salva,
    /// para não substituir um backup bom depois de uma falha que apagou os dados.
    @discardableResult
    func backUpIfNeeded(_ positions: [PortfolioBackup.Position], now: Date = .now) throws -> Bool {
        guard !positions.isEmpty else { return false }
        let sorted = positions.sorted { $0.ticker < $1.ticker }
        let latest = latestBackupURL()
        let latestBackup = latest.flatMap(read)
        if latestBackup?.positions == sorted { return false }

        try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        let destination: URL
        let createdAt: Date
        if let latest, let latestBackup, now.timeIntervalSince(latestBackup.createdAt) < Self.minimumInterval {
            destination = latest
            createdAt = latestBackup.createdAt
        } else {
            destination = backupsDirectory.appending(path: "\(Self.filePrefix)\(Int(now.timeIntervalSince1970)).json")
            createdAt = now
        }

        let backup = PortfolioBackup(createdAt: createdAt, positions: sorted)
        try Self.encoder.encode(backup).write(to: destination, options: .atomic)
        try pruneOldBackups()
        return true
    }

    @MainActor
    @discardableResult
    func backUpIfNeeded(_ holdings: [Holding], now: Date = .now) throws -> Bool {
        try backUpIfNeeded(holdings.map(PortfolioBackup.Position.init), now: now)
    }

    func latestBackupURL() -> URL? {
        backupURLs().last
    }

    func read(_ url: URL) -> PortfolioBackup? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(PortfolioBackup.self, from: data)
    }

    /// Deixa a cópia mais recente pronta para ser importada no próximo carregamento do banco.
    @discardableResult
    func stageLatestForRestore() throws -> Bool {
        guard let latest = latestBackupURL(), read(latest) != nil else { return false }
        let pending = directory.appending(path: Self.pendingRestoreName)
        if fileManager.fileExists(atPath: pending.path(percentEncoded: false)) {
            try fileManager.removeItem(at: pending)
        }
        try fileManager.copyItem(at: latest, to: pending)
        return true
    }

    /// Idempotente como o `LegacyStoreImporter`: tickers que já existem no destino são mantidos.
    @MainActor
    @discardableResult
    func importPendingRestore(into context: ModelContext) throws -> Bool {
        let pending = directory.appending(path: Self.pendingRestoreName)
        guard fileManager.fileExists(atPath: pending.path(percentEncoded: false)) else { return false }
        guard let backup = read(pending) else {
            try fileManager.removeItem(at: pending)
            return false
        }

        var heldTickers = Set(try context.fetch(FetchDescriptor<Holding>()).map(\.ticker))
        for position in backup.positions where heldTickers.insert(position.ticker).inserted {
            context.insert(Holding(
                ticker: position.ticker,
                shares: position.shares,
                averagePrice: position.averagePrice,
                purchasedAt: position.purchasedAt,
                updatedAt: position.updatedAt,
                notes: position.notes
            ))
        }
        try context.save()
        try fileManager.removeItem(at: pending)
        return true
    }

    private func backupURLs() -> [URL] {
        let names = (try? fileManager.contentsOfDirectory(atPath: backupsDirectory.path(percentEncoded: false))) ?? []
        return names
            .compactMap { name -> (timestamp: Int, name: String)? in
                guard name.hasPrefix(Self.filePrefix), name.hasSuffix(".json") else { return nil }
                let raw = name.dropFirst(Self.filePrefix.count).dropLast(".json".count)
                return Int(raw).map { ($0, name) }
            }
            .sorted { $0.timestamp < $1.timestamp }
            .map { backupsDirectory.appending(path: $0.name) }
    }

    private func pruneOldBackups() throws {
        for url in backupURLs().dropLast(Self.retainedBackups) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Datas no formato padrão (segundos desde 2001) para a ida e volta ser exata e a
    /// comparação com o último backup não acusar mudança por arredondamento.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
}
