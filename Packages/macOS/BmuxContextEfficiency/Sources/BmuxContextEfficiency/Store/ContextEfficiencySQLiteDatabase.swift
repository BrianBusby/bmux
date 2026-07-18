import Foundation
import SQLite3

final class ContextEfficiencySQLiteDatabase {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &opened, flags, nil) == SQLITE_OK, let opened else {
            let message = opened.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "open failed"
            if let opened {
                sqlite3_close(opened)
            }
            throw ContextEfficiencyStoreError.sqlite(message: message)
        }
        self.handle = opened
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func execute(_ sql: String) throws {
        guard let handle else {
            throw ContextEfficiencyStoreError.sqlite(message: "database is closed")
        }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? self.message
            sqlite3_free(errorMessage)
            throw ContextEfficiencyStoreError.sqlite(message: message)
        }
    }

    func prepare(_ sql: String) throws -> ContextEfficiencySQLiteStatement {
        guard let handle else {
            throw ContextEfficiencyStoreError.sqlite(message: "database is closed")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ContextEfficiencyStoreError.sqlite(message: message)
        }
        return ContextEfficiencySQLiteStatement(database: handle, statement: statement)
    }

    var userVersion: Int32 {
        get throws {
            let statement = try prepare("PRAGMA user_version")
            defer { statement.finalize() }
            guard try statement.step() else { return 0 }
            return statement.int32(at: 0)
        }
    }

    var changes: Int {
        guard let handle else { return 0 }
        return Int(sqlite3_changes(handle))
    }

    var message: String {
        guard let handle, let raw = sqlite3_errmsg(handle) else {
            return "unknown sqlite error"
        }
        return String(cString: raw)
    }
}
