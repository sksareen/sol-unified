//
//  ClipboardStore.swift
//  SolUnified
//
//  Clipboard data management
//

import Foundation
import AppKit
import CryptoKit

class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()
    
    @Published var items: [ClipboardItem] = []
    private let db = Database.shared
    private let maxItems = 100
    
    private init() {
        loadHistory()
    }
    
    func loadHistory(limit: Int = 100) {
        let results = db.query(
            "SELECT * FROM clipboard_history ORDER BY created_at DESC LIMIT ?",
            parameters: [limit]
        )
        
        items = results.map { itemFromRow($0) }
    }
    
    func saveItem(_ item: ClipboardItem) -> Bool {
        let sql = """
            INSERT OR IGNORE INTO clipboard_history 
            (content_type, content_text, content_preview, file_path, content_hash, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """
        
        let success = db.execute(sql, parameters: [
            item.contentType.rawValue,
            item.contentText ?? NSNull(),
            item.contentPreview ?? NSNull(),
            item.filePath ?? NSNull(),
            item.contentHash,
            Database.dateToString(item.createdAt)
        ])
        
        if success {
            pruneOldItems()
            loadHistory()
        }
        
        return success
    }
    
    func searchHistory(query: String) -> [ClipboardItem] {
        if query.isEmpty {
            return items
        }
        
        let results = db.query(
            """
            SELECT * FROM clipboard_history 
            WHERE content_text LIKE ? OR content_preview LIKE ?
            ORDER BY created_at DESC
            LIMIT 100
            """,
            parameters: ["%\(query)%", "%\(query)%"]
        )
        
        return results.map { itemFromRow($0) }
    }
    
    func copyToPasteboard(_ item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.contentType {
        case .text:
            if let text = item.contentText {
                pasteboard.setString(text, forType: .string)
                return true
            }
        case .image:
            if let path = item.filePath, let image = NSImage(contentsOfFile: path) {
                pasteboard.writeObjects([image])
                return true
            }
        case .file:
            if let path = item.filePath {
                let url = URL(fileURLWithPath: path)
                pasteboard.writeObjects([url as NSURL])
                return true
            }
        }
        
        return false
    }
    
    func clearHistory() -> Bool {
        let success = db.execute("DELETE FROM clipboard_history")
        if success {
            items = []
        }
        return success
    }
    
    func pruneOldItems() {
        // Keep only the last maxItems
        db.execute("""
            DELETE FROM clipboard_history
            WHERE id NOT IN (
                SELECT id FROM clipboard_history
                ORDER BY created_at DESC
                LIMIT ?
            )
            """, parameters: [maxItems])
    }
    
    // MARK: - Helpers
    private func itemFromRow(_ row: [String: Any]) -> ClipboardItem {
        ClipboardItem(
            id: row["id"] as? Int ?? 0,
            contentType: ContentType(rawValue: row["content_type"] as? String ?? "text") ?? .text,
            contentText: row["content_text"] as? String,
            contentPreview: row["content_preview"] as? String,
            filePath: row["file_path"] as? String,
            contentHash: row["content_hash"] as? String ?? "",
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date()
        )
    }
    
    static func hashContent(_ content: String) -> String {
        let data = Data(content.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

