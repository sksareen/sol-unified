//
//  NotesStore.swift
//  SolUnified
//
//  Notes data management and business logic
//

import Foundation

class NotesStore: ObservableObject {
    static let shared = NotesStore()
    
    @Published var notes: [Note] = []
    @Published var globalNote: Note?
    
    private let db = Database.shared
    
    private init() {
        loadGlobalNote()
        loadAllNotes()
    }
    
    // MARK: - Global Note
    func loadGlobalNote() {
        let results = db.query(
            "SELECT * FROM notes WHERE is_global = 1 LIMIT 1"
        )
        
        if let row = results.first {
            globalNote = noteFromRow(row)
        } else {
            // Create global note if it doesn't exist
            let note = Note(title: "Scratchpad", content: "", isGlobal: true)
            if saveNote(note) {
                globalNote = note
            }
        }
    }
    
    func saveGlobalNote(content: String) {
        guard var note = globalNote else { return }
        note.content = content
        note.updatedAt = Date()
        
        let sql = """
            UPDATE notes SET content = ?, updated_at = ?
            WHERE id = ?
            """
        
        db.execute(sql, parameters: [
            content,
            Database.dateToString(note.updatedAt),
            note.id
        ])
        
        globalNote = note
    }
    
    // MARK: - Notes CRUD
    func loadAllNotes() {
        let results = db.query(
            "SELECT * FROM notes WHERE is_global = 0 ORDER BY updated_at DESC"
        )
        
        notes = results.map { noteFromRow($0) }
    }
    
    func saveNote(_ note: Note) -> Bool {
        if note.id == 0 {
            // Insert new note
            let sql = """
                INSERT INTO notes (title, content, is_global, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """
            
            let success = db.execute(sql, parameters: [
                note.title,
                note.content,
                note.isGlobal ? 1 : 0,
                Database.dateToString(note.createdAt),
                Database.dateToString(note.updatedAt)
            ])
            
            if success {
                loadAllNotes()
            }
            return success
        } else {
            // Update existing note
            let sql = """
                UPDATE notes SET title = ?, content = ?, updated_at = ?
                WHERE id = ?
                """
            
            let success = db.execute(sql, parameters: [
                note.title,
                note.content,
                Database.dateToString(note.updatedAt),
                note.id
            ])
            
            if success {
                loadAllNotes()
            }
            return success
        }
    }
    
    func deleteNote(id: Int) -> Bool {
        let success = db.execute("DELETE FROM notes WHERE id = ?", parameters: [id])
        if success {
            loadAllNotes()
        }
        return success
    }
    
    func searchNotes(query: String) -> [Note] {
        if query.isEmpty {
            return notes
        }
        
        let results = db.query(
            """
            SELECT * FROM notes 
            WHERE is_global = 0 AND (title LIKE ? OR content LIKE ?)
            ORDER BY updated_at DESC
            """,
            parameters: ["%\(query)%", "%\(query)%"]
        )
        
        return results.map { noteFromRow($0) }
    }
    
    // MARK: - Helper
    private func noteFromRow(_ row: [String: Any]) -> Note {
        Note(
            id: row["id"] as? Int ?? 0,
            title: row["title"] as? String ?? "",
            content: row["content"] as? String ?? "",
            isGlobal: (row["is_global"] as? Int ?? 0) == 1,
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            updatedAt: Database.stringToDate(row["updated_at"] as? String ?? "") ?? Date()
        )
    }
}

