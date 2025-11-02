//
//  Database.swift
//  SolUnified
//
//  SQLite database wrapper and manager
//

import Foundation
import SQLite3

class Database {
    static let shared = Database()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("SolUnified", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        dbPath = appDirectory.appendingPathComponent("sol.db").path
        print("Database path: \(dbPath)")
    }
    
    func initialize() -> Bool {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database")
            return false
        }
        
        // Enable WAL mode for better concurrent access and performance
        if !execute("PRAGMA journal_mode=WAL;") {
            print("Warning: Failed to enable WAL mode")
        }
        
        return createTables()
    }
    
    private func createTables() -> Bool {
        let tables = [
            """
            CREATE TABLE IF NOT EXISTS notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT,
                content TEXT NOT NULL,
                is_global INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC)",
            
            """
            CREATE TABLE IF NOT EXISTS clipboard_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content_type TEXT NOT NULL,
                content_text TEXT,
                content_preview TEXT,
                file_path TEXT,
                content_hash TEXT UNIQUE,
                created_at TEXT NOT NULL
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_clipboard_created ON clipboard_history(created_at DESC)",
            
            """
            CREATE TABLE IF NOT EXISTS screenshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                filename TEXT UNIQUE NOT NULL,
                filepath TEXT NOT NULL,
                file_hash TEXT UNIQUE NOT NULL,
                file_size INTEGER,
                created_at TEXT,
                modified_at TEXT,
                width INTEGER,
                height INTEGER,
                ai_description TEXT,
                ai_tags TEXT,
                ai_text_content TEXT,
                analyzed_at TEXT,
                analysis_model TEXT
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_screenshots_filename ON screenshots(filename)",
            "CREATE INDEX IF NOT EXISTS idx_screenshots_created ON screenshots(created_at DESC)",
            
            """
            CREATE TABLE IF NOT EXISTS activity_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_type TEXT NOT NULL,
                app_bundle_id TEXT,
                app_name TEXT,
                window_title TEXT,
                event_data TEXT,
                timestamp TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_log(timestamp DESC)",
            "CREATE INDEX IF NOT EXISTS idx_activity_type ON activity_log(event_type)",
            "CREATE INDEX IF NOT EXISTS idx_activity_app ON activity_log(app_bundle_id)"
        ]
        
        for sql in tables {
            if !execute(sql) {
                print("Failed to create table: \(sql)")
                return false
            }
        }
        
        return true
    }
    
    @discardableResult
    func execute(_ sql: String, parameters: [Any] = []) -> Bool {
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing statement: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        // Bind parameters
        for (index, param) in parameters.enumerated() {
            let bindIndex = Int32(index + 1)
            if let text = param as? String {
                sqlite3_bind_text(statement, bindIndex, (text as NSString).utf8String, -1, nil)
            } else if let number = param as? Int {
                sqlite3_bind_int64(statement, bindIndex, Int64(number))
            } else if let number = param as? Double {
                sqlite3_bind_double(statement, bindIndex, number)
            } else if param is NSNull {
                sqlite3_bind_null(statement, bindIndex)
            }
        }
        
        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)
        
        return result == SQLITE_DONE || result == SQLITE_ROW
    }
    
    func query(_ sql: String, parameters: [Any] = []) -> [[String: Any]] {
        var statement: OpaquePointer?
        var results: [[String: Any]] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing query: \(String(cString: sqlite3_errmsg(db)))")
            return results
        }
        
        // Bind parameters
        for (index, param) in parameters.enumerated() {
            let bindIndex = Int32(index + 1)
            if let text = param as? String {
                sqlite3_bind_text(statement, bindIndex, (text as NSString).utf8String, -1, nil)
            } else if let number = param as? Int {
                sqlite3_bind_int64(statement, bindIndex, Int64(number))
            } else if let number = param as? Double {
                sqlite3_bind_double(statement, bindIndex, number)
            }
        }
        
        // Fetch results
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            let columnCount = sqlite3_column_count(statement)
            
            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                let columnType = sqlite3_column_type(statement, i)
                
                switch columnType {
                case SQLITE_INTEGER:
                    row[columnName] = Int(sqlite3_column_int64(statement, i))
                case SQLITE_FLOAT:
                    row[columnName] = sqlite3_column_double(statement, i)
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(statement, i) {
                        row[columnName] = String(cString: text)
                    }
                case SQLITE_NULL:
                    row[columnName] = NSNull()
                default:
                    break
                }
            }
            
            results.append(row)
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func lastInsertRowId() -> Int {
        return Int(sqlite3_last_insert_rowid(db))
    }
    
    // MARK: - Activity Log Methods
    
    func insertActivityEvents(_ events: [ActivityEvent]) -> Bool {
        guard !events.isEmpty else { return true }
        
        if !beginTransaction() {
            print("Failed to begin transaction for activity events")
            return false
        }
        
        let sql = """
            INSERT INTO activity_log (event_type, app_bundle_id, app_name, window_title, event_data, timestamp, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        
        var success = true
        for event in events {
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                print("Error preparing activity event insert: \(String(cString: sqlite3_errmsg(db)))")
                success = false
                break
            }
            
            // Bind parameters
            sqlite3_bind_text(statement, 1, (event.eventType.rawValue as NSString).utf8String, -1, nil)
            
            if let bundleId = event.appBundleId {
                sqlite3_bind_text(statement, 2, (bundleId as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 2)
            }
            
            if let appName = event.appName {
                sqlite3_bind_text(statement, 3, (appName as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 3)
            }
            
            if let windowTitle = event.windowTitle {
                sqlite3_bind_text(statement, 4, (windowTitle as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            
            if let eventData = event.eventData {
                sqlite3_bind_text(statement, 5, (eventData as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 5)
            }
            
            sqlite3_bind_text(statement, 6, (Database.dateToString(event.timestamp) as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 7, (Database.dateToString(event.createdAt) as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error inserting activity event: \(String(cString: sqlite3_errmsg(db)))")
                success = false
            }
            
            sqlite3_finalize(statement)
            
            if !success {
                break
            }
        }
        
        if success {
            if !commitTransaction() {
                print("Failed to commit transaction for activity events")
                success = false
            }
        } else {
            _ = rollbackTransaction()
        }
        
        return success
    }
    
    func cleanupOldActivityLogs(olderThan days: Int) -> Bool {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffString = Database.dateToString(cutoffDate)
        
        return execute(
            "DELETE FROM activity_log WHERE timestamp < ?",
            parameters: [cutoffString]
        )
    }
    
    // MARK: - Transaction Helpers
    
    private func beginTransaction() -> Bool {
        return execute("BEGIN TRANSACTION")
    }
    
    private func commitTransaction() -> Bool {
        return execute("COMMIT")
    }
    
    private func rollbackTransaction() -> Bool {
        return execute("ROLLBACK")
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
}

// MARK: - Date Helpers
extension Database {
    static func dateToString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
    
    static func stringToDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}

