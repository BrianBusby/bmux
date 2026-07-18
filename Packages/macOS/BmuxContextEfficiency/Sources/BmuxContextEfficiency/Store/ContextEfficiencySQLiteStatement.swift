import Foundation
import SQLite3

final class ContextEfficiencySQLiteStatement {
    private let database: OpaquePointer
    private var statement: OpaquePointer?

    init(database: OpaquePointer, statement: OpaquePointer) {
        self.database = database
        self.statement = statement
    }

    deinit {
        finalize()
    }

    func finalize() {
        if let statement {
            sqlite3_finalize(statement)
            self.statement = nil
        }
    }

    func bind(_ value: String?, at index: Int32) throws {
        guard let statement else { return }
        if let value {
            let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
            guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
                throw ContextEfficiencyStoreError.sqlite(message: message)
            }
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw ContextEfficiencyStoreError.sqlite(message: message)
            }
        }
    }

    func bind(_ value: Int64?, at index: Int32) throws {
        guard let statement else { return }
        if let value {
            guard sqlite3_bind_int64(statement, index, sqlite3_int64(value)) == SQLITE_OK else {
                throw ContextEfficiencyStoreError.sqlite(message: message)
            }
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw ContextEfficiencyStoreError.sqlite(message: message)
            }
        }
    }

    func bind(_ value: Int, at index: Int32) throws {
        try bind(Int64(value), at: index)
    }

    func bind(_ value: Double?, at index: Int32) throws {
        guard let statement else { return }
        if let value {
            guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
                throw ContextEfficiencyStoreError.sqlite(message: message)
            }
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw ContextEfficiencyStoreError.sqlite(message: message)
            }
        }
    }

    func step() throws -> Bool {
        guard let statement else { return false }
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            return true
        }
        if result == SQLITE_DONE {
            return false
        }
        throw ContextEfficiencyStoreError.sqlite(message: message)
    }

    func string(at index: Int32) -> String? {
        guard let statement, let raw = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: raw)
    }

    func int64(at index: Int32) -> Int64 {
        guard let statement else { return 0 }
        return sqlite3_column_int64(statement, index)
    }

    func optionalInt64(at index: Int32) -> Int64? {
        guard let statement else { return nil }
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_int64(statement, index)
    }

    func int(at index: Int32) -> Int {
        Int(int64(at: index))
    }

    func int32(at index: Int32) -> Int32 {
        guard let statement else { return 0 }
        return sqlite3_column_int(statement, index)
    }

    func double(at index: Int32) -> Double? {
        guard let statement else { return nil }
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_double(statement, index)
    }

    private var message: String {
        guard let raw = sqlite3_errmsg(database) else {
            return "unknown sqlite error"
        }
        return String(cString: raw)
    }
}
