//
//  DailyNoteManager.swift
//  SolUnified
//
//  Manages daily note creation and access
//

import Foundation

class DailyNoteManager: ObservableObject {
    static let shared = DailyNoteManager()
    
    private init() {}
    
    /// Formats a date using the specified format string
    func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    /// Gets the path to today's daily note file
    func getTodaysNotePath(vaultRoot: String, journalFolder: String, dateFormat: String) -> URL {
        let dateString = formatDate(Date(), format: dateFormat)
        let fileName = "\(dateString).md"
        
        var folderPath = URL(fileURLWithPath: vaultRoot)
        
        // Add journal folder path if specified
        if !journalFolder.isEmpty {
            folderPath = folderPath.appendingPathComponent(journalFolder)
        }
        
        return folderPath.appendingPathComponent(fileName)
    }
    
    /// Creates or gets today's daily note, returns the URL if successful
    func getOrCreateTodaysNote(vaultRoot: String, journalFolder: String, dateFormat: String, template: String) -> URL? {
        let fileURL = getTodaysNotePath(vaultRoot: vaultRoot, journalFolder: journalFolder, dateFormat: dateFormat)
        let fileManager = FileManager.default
        
        // Check if file already exists
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        // Create the directory if it doesn't exist
        let folderURL = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating daily notes folder: \(error)")
            return nil
        }
        
        // Create the file with template content
        do {
            try template.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error creating daily note: \(error)")
            return nil
        }
    }
    
    /// Creates a new markdown file at the specified path
    func createNewFile(at folderURL: URL, fileName: String, content: String = "") -> URL? {
        let fileManager = FileManager.default
        
        // Ensure filename has .md extension
        var finalFileName = fileName
        if !finalFileName.hasSuffix(".md") {
            finalFileName += ".md"
        }
        
        let fileURL = folderURL.appendingPathComponent(finalFileName)
        
        // Check if file already exists
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL // Just return existing file
        }
        
        // Create the directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating folder: \(error)")
            return nil
        }
        
        // Create the file
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error creating file: \(error)")
            return nil
        }
    }
}

