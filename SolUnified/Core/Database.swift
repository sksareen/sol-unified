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
    private let dbQueue = DispatchQueue(label: "com.solunified.database", qos: .utility)
    
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
        var result: Bool = false
        dbQueue.sync {
            if sqlite3_open(dbPath, &db) != SQLITE_OK {
                print("Error opening database")
                result = false
                return
            }
            
            // Enable WAL mode for better concurrent access and performance
            if !executeSync("PRAGMA journal_mode=WAL;") {
                print("Warning: Failed to enable WAL mode")
            }
            
            // Create base tables first (without indexes that depend on columns that might not exist)
            result = createBaseTablesSync()
            
            // Always run migrations to ensure schema is up to date
            if result {
                performMigrationsSync()
            }
            
            // Now create indexes (columns should exist after migrations)
            if result {
                createIndexesSync()
            }
        }
        return result
    }
    
    private func performMigrationsSync() {
        // Migration: Add sequence_id to activity_log if missing
        let checkColumnSql = "PRAGMA table_info(activity_log);"
        let columns = querySync(checkColumnSql)
        let hasSequenceId = columns.contains { ($0["name"] as? String) == "sequence_id" }
        
        if !hasSequenceId {
            print("Migrating: Adding sequence_id to activity_log")
            if executeSync("ALTER TABLE activity_log ADD COLUMN sequence_id TEXT") {
                _ = executeSync("CREATE INDEX IF NOT EXISTS idx_activity_sequence ON activity_log(sequence_id)")
            } else {
                print("Error adding sequence_id column")
            }
        }
        
        // Migration: Add source metadata columns to clipboard_history
        let checkClipboardColumnSql = "PRAGMA table_info(clipboard_history);"
        let clipboardColumns = querySync(checkClipboardColumnSql)
        let hasClipboardSourceApp = clipboardColumns.contains { ($0["name"] as? String) == "source_app_bundle_id" }
        
        if !hasClipboardSourceApp {
            print("Migrating: Adding source metadata to clipboard_history")
            _ = executeSync("ALTER TABLE clipboard_history ADD COLUMN source_app_bundle_id TEXT")
            _ = executeSync("ALTER TABLE clipboard_history ADD COLUMN source_app_name TEXT")
            _ = executeSync("ALTER TABLE clipboard_history ADD COLUMN source_window_title TEXT")
            print("Migration complete: clipboard_history source metadata columns added")
        }
        
        // Migration: Add source metadata columns to screenshots
        let checkScreenshotColumnSql = "PRAGMA table_info(screenshots);"
        let screenshotColumns = querySync(checkScreenshotColumnSql)
        let hasScreenshotSourceApp = screenshotColumns.contains { ($0["name"] as? String) == "source_app_bundle_id" }
        
        if !hasScreenshotSourceApp {
            print("Migrating: Adding source metadata to screenshots")
            _ = executeSync("ALTER TABLE screenshots ADD COLUMN source_app_bundle_id TEXT")
            _ = executeSync("ALTER TABLE screenshots ADD COLUMN source_app_name TEXT")
            _ = executeSync("ALTER TABLE screenshots ADD COLUMN source_window_title TEXT")
            print("Migration complete: screenshots source metadata columns added")
        }
        
        // Migration: Create context graph tables
        _ = executeSync("""
            CREATE TABLE IF NOT EXISTS context_nodes (
                id TEXT PRIMARY KEY,
                label TEXT NOT NULL,
                type TEXT NOT NULL,
                start_time TEXT NOT NULL,
                end_time TEXT,
                is_active INTEGER DEFAULT 0,
                apps TEXT,
                window_titles TEXT,
                event_count INTEGER DEFAULT 0,
                focus_score REAL DEFAULT 0,
                parent_context_id TEXT,
                clipboard_hashes TEXT,
                screenshot_filenames TEXT,
                note_ids TEXT
            )
        """)
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_context_nodes_start ON context_nodes(start_time DESC)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_context_nodes_active ON context_nodes(is_active)")
        
        _ = executeSync("""
            CREATE TABLE IF NOT EXISTS context_edges (
                id TEXT PRIMARY KEY,
                from_context_id TEXT NOT NULL,
                to_context_id TEXT NOT NULL,
                edge_type TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                metadata TEXT,
                FOREIGN KEY (from_context_id) REFERENCES context_nodes(id),
                FOREIGN KEY (to_context_id) REFERENCES context_nodes(id)
            )
        """)
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_context_edges_timestamp ON context_edges(timestamp DESC)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_context_edges_from ON context_edges(from_context_id)")
        
        // Migration: Add context_id to activity_log for linking events to contexts
        let checkActivityContextSql = "PRAGMA table_info(activity_log);"
        let activityColumns = querySync(checkActivityContextSql)
        let hasContextId = activityColumns.contains { ($0["name"] as? String) == "context_id" }
        
        if !hasContextId {
            print("Migrating: Adding context_id to activity_log")
            _ = executeSync("ALTER TABLE activity_log ADD COLUMN context_id TEXT")
            _ = executeSync("ALTER TABLE activity_log ADD COLUMN enhanced_metadata TEXT")
            print("Migration complete: activity_log context columns added")
        }
        
        // Migration: Add context_id to clipboard_history
        let checkClipboardContextSql = "PRAGMA table_info(clipboard_history);"
        let clipboardContextColumns = querySync(checkClipboardContextSql)
        let hasClipboardContextId = clipboardContextColumns.contains { ($0["name"] as? String) == "context_id" }
        
        if !hasClipboardContextId {
            print("Migrating: Adding context_id to clipboard_history")
            _ = executeSync("ALTER TABLE clipboard_history ADD COLUMN context_id TEXT")
            print("Migration complete: clipboard_history context column added")
        }
        
        // Migration: Add context_id to screenshots
        let checkScreenshotContextSql = "PRAGMA table_info(screenshots);"
        let screenshotContextColumns = querySync(checkScreenshotContextSql)
        let hasScreenshotContextId = screenshotContextColumns.contains { ($0["name"] as? String) == "context_id" }

        if !hasScreenshotContextId {
            print("Migrating: Adding context_id to screenshots")
            _ = executeSync("ALTER TABLE screenshots ADD COLUMN context_id TEXT")
            print("Migration complete: screenshots context column added")
        }

        // MARK: - AI Agent Tables Migration

        // Migration: Create contacts table
        _ = executeSync("""
            CREATE TABLE IF NOT EXISTS contacts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                nickname TEXT,
                email TEXT,
                phone TEXT,
                relationship TEXT DEFAULT 'other',
                company TEXT,
                role TEXT,
                notes TEXT,
                preferences TEXT,
                last_interaction TEXT,
                interaction_count INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_contacts_name ON contacts(name)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_contacts_relationship ON contacts(relationship)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_contacts_last_interaction ON contacts(last_interaction DESC)")

        // Migration: Create contact_interactions table
        _ = executeSync("""
            CREATE TABLE IF NOT EXISTS contact_interactions (
                id TEXT PRIMARY KEY,
                contact_id TEXT NOT NULL,
                type TEXT NOT NULL,
                summary TEXT,
                timestamp TEXT NOT NULL,
                context_node_id TEXT,
                metadata TEXT,
                FOREIGN KEY (contact_id) REFERENCES contacts(id)
            )
        """)
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_contact_interactions_contact ON contact_interactions(contact_id)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_contact_interactions_timestamp ON contact_interactions(timestamp DESC)")

        // Migration: Create memories table (long-term facts/preferences)
        _ = executeSync("""
            CREATE TABLE IF NOT EXISTS memories (
                id TEXT PRIMARY KEY,
                category TEXT NOT NULL,
                key TEXT NOT NULL,
                value TEXT NOT NULL,
                confidence REAL DEFAULT 1.0,
                source TEXT DEFAULT 'inferred',
                last_confirmed TEXT,
                usage_count INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_memories_category ON memories(category)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_memories_key ON memories(key)")
        _ = executeSync("CREATE UNIQUE INDEX IF NOT EXISTS idx_memories_category_key ON memories(category, key)")

        // Migration: Create conversations table
        _ = executeSync("""
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                title TEXT,
                status TEXT DEFAULT 'active',
                context_snapshot TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_conversations_status ON conversations(status)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC)")

        // Migration: Create chat_messages table
        _ = executeSync("""
            CREATE TABLE IF NOT EXISTS chat_messages (
                id TEXT PRIMARY KEY,
                conversation_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                tool_calls TEXT,
                tool_results TEXT,
                timestamp TEXT NOT NULL,
                FOREIGN KEY (conversation_id) REFERENCES conversations(id)
            )
        """)
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation ON chat_messages(conversation_id)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages(timestamp)")

        // Migration: Create agent_actions table
        _ = executeSync("""
            CREATE TABLE IF NOT EXISTS agent_actions (
                id TEXT PRIMARY KEY,
                conversation_id TEXT,
                action_type TEXT NOT NULL,
                parameters TEXT NOT NULL,
                status TEXT DEFAULT 'pending',
                result TEXT,
                error TEXT,
                created_at TEXT NOT NULL,
                executed_at TEXT,
                FOREIGN KEY (conversation_id) REFERENCES conversations(id)
            )
        """)
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_agent_actions_status ON agent_actions(status)")
        _ = executeSync("CREATE INDEX IF NOT EXISTS idx_agent_actions_conversation ON agent_actions(conversation_id)")
    }
    
    private func createTables() -> Bool {
        var result: Bool = false
        dbQueue.sync {
            result = self.createBaseTablesSync()
        }
        return result
    }
    
    /// Create base tables only (no indexes) - indexes are created after migrations
    private func createBaseTablesSync() -> Bool {
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
            
            """
            CREATE TABLE IF NOT EXISTS sequences (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                start_time TEXT NOT NULL,
                end_time TEXT,
                status TEXT NOT NULL,
                metadata TEXT
            )
            """,
            
            """
            CREATE TABLE IF NOT EXISTS neural_values (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                focus_score REAL,
                velocity_score REAL,
                primary_activity TEXT,
                intervention_active INTEGER DEFAULT 0,
                energy_level REAL,
                context_label TEXT,
                created_at TEXT NOT NULL
            )
            """
        ]
        
        for sql in tables {
            if !executeSync(sql) {
                print("Failed to create table: \(sql)")
                return false
            }
        }
        
        return true
    }
    
    /// Create indexes after migrations have ensured all columns exist
    private func createIndexesSync() {
        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC)",
            "CREATE INDEX IF NOT EXISTS idx_clipboard_created ON clipboard_history(created_at DESC)",
            "CREATE INDEX IF NOT EXISTS idx_clipboard_source_app ON clipboard_history(source_app_bundle_id)",
            "CREATE INDEX IF NOT EXISTS idx_screenshots_filename ON screenshots(filename)",
            "CREATE INDEX IF NOT EXISTS idx_screenshots_created ON screenshots(created_at DESC)",
            "CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_log(timestamp DESC)",
            "CREATE INDEX IF NOT EXISTS idx_activity_type ON activity_log(event_type)",
            "CREATE INDEX IF NOT EXISTS idx_activity_app ON activity_log(app_bundle_id)",
            "CREATE INDEX IF NOT EXISTS idx_activity_sequence ON activity_log(sequence_id)",
            "CREATE INDEX IF NOT EXISTS idx_sequences_start ON sequences(start_time DESC)",
            "CREATE INDEX IF NOT EXISTS idx_neural_timestamp ON neural_values(timestamp DESC)"
        ]
        
        for sql in indexes {
            if !executeSync(sql) {
                print("Warning: Failed to create index: \(sql)")
                // Don't fail on index creation - just log warning
            }
        }
    }
    
    @discardableResult
    func execute(_ sql: String, parameters: [Any] = []) -> Bool {
        var result: Bool = false
        dbQueue.sync {
            result = self.executeSync(sql, parameters: parameters)
        }
        return result
    }
    
    private func executeSync(_ sql: String, parameters: [Any] = []) -> Bool {
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
        
        let stepResult = sqlite3_step(statement)
        sqlite3_finalize(statement)
        
        return stepResult == SQLITE_DONE || stepResult == SQLITE_ROW
    }
    
    func query(_ sql: String, parameters: [Any] = []) -> [[String: Any]] {
        var results: [[String: Any]] = []
        dbQueue.sync {
            results = self.querySync(sql, parameters: parameters)
        }
        return results
    }
    
    private func querySync(_ sql: String, parameters: [Any] = []) -> [[String: Any]] {
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
        var rowId: Int = 0
        dbQueue.sync {
            rowId = Int(sqlite3_last_insert_rowid(db))
        }
        return rowId
    }
    
    // MARK: - Activity Log Methods
    
    func insertActivityEvents(_ events: [ActivityEvent]) -> Bool {
        guard !events.isEmpty else { return true }
        
        var result: Bool = false
        dbQueue.sync {
            result = self.insertActivityEventsSync(events)
        }
        return result
    }
    
    private func insertActivityEventsSync(_ events: [ActivityEvent]) -> Bool {
        if !beginTransactionSync() {
            print("Failed to begin transaction for activity events")
            return false
        }
        
        let sql = """
            INSERT INTO activity_log (event_type, app_bundle_id, app_name, window_title, event_data, timestamp, created_at, sequence_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
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
            
            if let sequenceId = event.sequenceId {
                sqlite3_bind_text(statement, 8, (sequenceId as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 8)
            }
            
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
            if !commitTransactionSync() {
                print("Failed to commit transaction for activity events")
                success = false
            }
        } else {
            _ = rollbackTransactionSync()
        }
        
        return success
    }
    
    // MARK: - Sequence Methods
    
    func insertSequence(_ sequence: Sequence) -> Bool {
        return execute(
            """
            INSERT OR REPLACE INTO sequences (id, type, start_time, end_time, status, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                sequence.id,
                sequence.type.rawValue,
                Database.dateToString(sequence.startTime),
                sequence.endTime.map { Database.dateToString($0) } as Any,
                sequence.status.rawValue,
                sequence.metadata as Any
            ]
        )
    }
    
    func getSequence(id: String) -> Sequence? {
        let results = query("SELECT * FROM sequences WHERE id = ?", parameters: [id])
        guard let row = results.first else { return nil }
        
        return Sequence(
            id: row["id"] as? String ?? "",
            type: SequenceType(rawValue: row["type"] as? String ?? "") ?? .custom,
            startTime: Database.stringToDate(row["start_time"] as? String ?? "") ?? Date(),
            endTime: Database.stringToDate(row["end_time"] as? String ?? ""),
            status: SequenceStatus(rawValue: row["status"] as? String ?? "") ?? .active,
            metadata: row["metadata"] as? String
        )
    }
    
    func updateSequenceStatus(id: String, status: SequenceStatus, endTime: Date? = nil) -> Bool {
        var sql = "UPDATE sequences SET status = ?"
        var params: [Any] = [status.rawValue]
        
        if let end = endTime {
            sql += ", end_time = ?"
            params.append(Database.dateToString(end))
        }
        
        sql += " WHERE id = ?"
        params.append(id)
        
        return execute(sql, parameters: params)
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
    
    private func beginTransactionSync() -> Bool {
        return executeSync("BEGIN TRANSACTION")
    }
    
    private func commitTransaction() -> Bool {
        return execute("COMMIT")
    }
    
    private func commitTransactionSync() -> Bool {
        return executeSync("COMMIT")
    }
    
    private func rollbackTransaction() -> Bool {
        return execute("ROLLBACK")
    }
    
    private func rollbackTransactionSync() -> Bool {
        return executeSync("ROLLBACK")
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

