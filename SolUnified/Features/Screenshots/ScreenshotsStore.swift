//
//  ScreenshotsStore.swift
//  SolUnified
//
//  Screenshot data management
//

import Foundation

class ScreenshotsStore: ObservableObject {
    static let shared = ScreenshotsStore()
    
    @Published var screenshots: [Screenshot] = []
    @Published var stats: ScreenshotStats?
    
    private let db = Database.shared
    
    private init() {}
    
    func loadScreenshots(search: String? = nil, limit: Int = 100, offset: Int = 0) {
        var sql = "SELECT * FROM screenshots"
        var parameters: [Any] = []
        
        if let search = search, !search.isEmpty {
            sql += """
                 WHERE ai_description LIKE ? 
                    OR ai_tags LIKE ? 
                    OR ai_text_content LIKE ?
                    OR filename LIKE ?
                """
            parameters = ["%\(search)%", "%\(search)%", "%\(search)%", "%\(search)%"]
        }
        
        sql += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
        parameters.append(limit)
        parameters.append(offset)
        
        print("🔍 Loading screenshots: \(sql) with \(parameters.count) params")
        let results = db.query(sql, parameters: parameters)
        print("📸 Loaded \(results.count) screenshots from database")
        screenshots = results.map { screenshotFromRow($0) }
        print("✅ Converted to \(screenshots.count) Screenshot objects")
    }
    
    func getScreenshot(id: Int) -> Screenshot? {
        let results = db.query("SELECT * FROM screenshots WHERE id = ?", parameters: [id])
        return results.first.map { screenshotFromRow($0) }
    }
    
    func updateScreenshot(_ screenshot: Screenshot) -> Bool {
        let sql = """
            UPDATE screenshots SET 
                ai_description = ?,
                ai_tags = ?,
                ai_text_content = ?,
                analyzed_at = ?,
                analysis_model = ?
            WHERE id = ?
            """
        
        return db.execute(sql, parameters: [
            screenshot.aiDescription ?? NSNull(),
            screenshot.aiTags ?? NSNull(),
            screenshot.aiTextContent ?? NSNull(),
            screenshot.analyzedAt.map { Database.dateToString($0) } ?? NSNull(),
            screenshot.analysisModel ?? NSNull(),
            screenshot.id
        ])
    }
    
    func getStats() {
        let countResult = db.query("SELECT COUNT(*) as count FROM screenshots")
        let totalCount = countResult.first?["count"] as? Int ?? 0
        
        let sizeResult = db.query("SELECT SUM(file_size) as size FROM screenshots")
        let totalSize = sizeResult.first?["size"] as? Int ?? 0
        let totalSizeMB = Double(totalSize) / (1024 * 1024)
        
        let tagsResult = db.query("""
            SELECT ai_tags, COUNT(*) as count 
            FROM screenshots 
            WHERE ai_tags IS NOT NULL 
            GROUP BY ai_tags 
            ORDER BY count DESC 
            LIMIT 10
            """)
        
        let topTags = tagsResult.map { row in
            ScreenshotStats.TagCount(
                tag: row["ai_tags"] as? String ?? "",
                count: row["count"] as? Int ?? 0
            )
        }
        
        stats = ScreenshotStats(
            totalScreenshots: totalCount,
            totalSizeMB: totalSizeMB,
            topTags: topTags
        )
    }
    
    private func screenshotFromRow(_ row: [String: Any]) -> Screenshot {
        Screenshot(
            id: row["id"] as? Int ?? 0,
            filename: row["filename"] as? String ?? "",
            filepath: row["filepath"] as? String ?? "",
            fileHash: row["file_hash"] as? String ?? "",
            fileSize: row["file_size"] as? Int ?? 0,
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            modifiedAt: Database.stringToDate(row["modified_at"] as? String ?? "") ?? Date(),
            width: row["width"] as? Int ?? 0,
            height: row["height"] as? Int ?? 0,
            aiDescription: row["ai_description"] as? String,
            aiTags: row["ai_tags"] as? String,
            aiTextContent: row["ai_text_content"] as? String,
            analyzedAt: (row["analyzed_at"] as? String).flatMap { Database.stringToDate($0) },
            analysisModel: row["analysis_model"] as? String
        )
    }
}

