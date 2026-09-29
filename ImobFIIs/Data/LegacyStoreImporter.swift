import Foundation
import SQLite3
import SwiftData

/// Copia o banco único da versão 1 (`default.store`) para os stores da versão 2
/// e move o arquivo antigo para `LegacyStoreBackup/` em vez de apagá-lo.
///
/// Lê o SQLite direto: abrir o arquivo antigo com modelos SwiftData de mesmo nome de
/// entidade (`Fund`, `Holding`) no mesmo processo que o container novo não é suportado.
enum LegacyStoreImporter {
    static let backupDirectoryName = "LegacyStoreBackup"

    enum ImportError: Error {
        case cannotOpen(String)
        case query(String)
    }

    @MainActor
    @discardableResult
    static func importIfNeeded(
        from legacyURL: URL,
        into context: ModelContext,
        fileManager: FileManager = .default,
        now: Date = .now
    ) throws -> Bool {
        guard fileManager.fileExists(atPath: legacyURL.path(percentEncoded: false)) else { return false }
        try importStore(at: legacyURL, into: context)
        try moveToBackup(legacyURL, fileManager: fileManager, now: now)
        return true
    }

    /// Idempotente: fundos e posições cujo ticker já existe no destino são mantidos como estão.
    @MainActor
    static func importStore(at legacyURL: URL, into context: ModelContext) throws {
        let database = try LegacyDatabase(url: legacyURL)

        var cachedTickers = Set(try context.fetch(FetchDescriptor<Fund>()).map(\.ticker))
        for fund in try database.funds() where cachedTickers.insert(fund.ticker).inserted {
            context.insert(fund)
        }

        var heldTickers = Set(try context.fetch(FetchDescriptor<Holding>()).map(\.ticker))
        for holding in try database.holdings() where heldTickers.insert(holding.ticker).inserted {
            context.insert(holding)
        }

        try context.save()
    }

    private static func moveToBackup(_ legacyURL: URL, fileManager: FileManager, now: Date) throws {
        let backupDirectory = legacyURL
            .deletingLastPathComponent()
            .appending(path: backupDirectoryName)
            .appending(path: String(Int(now.timeIntervalSince1970)))
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let name = legacyURL.lastPathComponent
        for suffix in ["", "-shm", "-wal"] {
            let source = legacyURL.deletingLastPathComponent().appending(path: name + suffix)
            guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
            try fileManager.moveItem(at: source, to: backupDirectory.appending(path: name + suffix))
        }
    }
}

/// Tabelas geradas pelo Core Data para o schema V1: `ZFUND` e `ZHOLDING` (com `ZFUND` como FK).
private final class LegacyDatabase {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        guard sqlite3_open_v2(url.path(percentEncoded: false), &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2"
            sqlite3_close(handle)
            throw LegacyStoreImporter.ImportError.cannotOpen(message)
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    func funds() throws -> [Fund] {
        try rows(
            """
            SELECT ZTICKER, ZNAME, ZSEGMENTRAW, ZMANAGER, ZCURRENTPRICE, ZDIVIDENDYIELD,
                   ZLASTDIVIDEND, ZLASTDIVIDENDUPDATEDAT, ZVACANCYRATE
            FROM ZFUND WHERE ZTICKER IS NOT NULL
            """
        ) { row in
            let fund = Fund(
                ticker: row.text(0) ?? "",
                name: row.text(1) ?? "",
                segment: .other,
                manager: row.text(3) ?? "",
                currentPrice: row.decimal(4) ?? 0,
                dividendYield: row.double(5) ?? 0,
                lastDividend: row.decimal(6) ?? 0,
                lastDividendUpdatedAt: row.date(7),
                vacancyRate: row.double(8)
            )
            fund.segmentRaw = row.text(2) ?? FundSegment.other.rawValue
            return fund
        }
    }

    func holdings() throws -> [Holding] {
        try rows(
            """
            SELECT f.ZTICKER, h.ZSHARES, h.ZAVERAGEPRICE, h.ZPURCHASEDAT, h.ZNOTES
            FROM ZHOLDING h JOIN ZFUND f ON f.Z_PK = h.ZFUND
            WHERE f.ZTICKER IS NOT NULL
            ORDER BY h.Z_PK
            """
        ) { row in
            Holding(
                ticker: row.text(0) ?? "",
                shares: row.int(1) ?? 0,
                averagePrice: row.decimal(2) ?? 0,
                purchasedAt: row.date(3) ?? .now,
                notes: row.text(4) ?? ""
            )
        }
    }

    private func rows<T>(_ sql: String, map: (LegacyRow) -> T) throws -> [T] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LegacyStoreImporter.ImportError.query(String(cString: sqlite3_errmsg(handle)))
        }

        var result: [T] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                result.append(map(LegacyRow(statement: statement)))
            case SQLITE_DONE:
                return result
            default:
                throw LegacyStoreImporter.ImportError.query(String(cString: sqlite3_errmsg(handle)))
            }
        }
    }
}

private struct LegacyRow {
    let statement: OpaquePointer?

    private func isNull(_ column: Int32) -> Bool {
        sqlite3_column_type(statement, column) == SQLITE_NULL
    }

    func text(_ column: Int32) -> String? {
        guard !isNull(column), let value = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: value)
    }

    func int(_ column: Int32) -> Int? {
        isNull(column) ? nil : Int(sqlite3_column_int64(statement, column))
    }

    func double(_ column: Int32) -> Double? {
        isNull(column) ? nil : sqlite3_column_double(statement, column)
    }

    /// Core Data grava `Decimal` como número; o texto evita o arredondamento binário do `Double`.
    func decimal(_ column: Int32) -> Decimal? {
        text(column).flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
    }

    /// Core Data grava datas em segundos desde 2001-01-01 (reference date).
    func date(_ column: Int32) -> Date? {
        double(column).map(Date.init(timeIntervalSinceReferenceDate:))
    }
}
