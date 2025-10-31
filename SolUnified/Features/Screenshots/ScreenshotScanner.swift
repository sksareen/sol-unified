//
//  ScreenshotScanner.swift
//  SolUnified
//
//  Native screenshot file scanner and analyzer
//

import Foundation
import AppKit
import CryptoKit
import ImageIO
import CoreGraphics

class ScreenshotScanner: ObservableObject {
    static let shared = ScreenshotScanner()
    
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    
    private let db = Database.shared
    
    private init() {}
    
    func scanDirectory(_ directoryPath: String) async throws -> ScanResult {
        await MainActor.run {
            isScanning = true
            scanProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isScanning = false
                scanProgress = 0.0
            }
        }
        
        // Expand tilde and resolve path
        let expandedPath = (directoryPath as NSString).expandingTildeInPath
        let directoryURL = URL(fileURLWithPath: expandedPath)
        
        print("📁 Scanning directory: \(directoryURL.path)")
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            print("❌ Directory does not exist: \(directoryURL.path)")
            throw NSError(domain: "Directory does not exist", code: -1, userInfo: [NSLocalizedDescriptionKey: "Directory does not exist: \(directoryURL.path)"])
        }
        
        guard let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]) else {
            print("❌ Failed to read directory contents")
            throw NSError(domain: "Failed to read directory", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read directory: \(directoryURL.path)"])
        }
        
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "bmp"]
        let imageFiles = files.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        
        print("📸 Found \(imageFiles.count) image files")
        
        if imageFiles.isEmpty {
            print("⚠️ No image files found in directory")
        }
        
        var stats = ScanResult(totalFiles: imageFiles.count, newFiles: 0, existingFiles: 0, errors: 0)
        
        // Get existing hashes
        let existingHashes = Set(db.query("SELECT file_hash FROM screenshots").compactMap { $0["file_hash"] as? String })
        print("💾 Found \(existingHashes.count) existing screenshots in database")
        
        for (index, fileURL) in imageFiles.enumerated() {
            await MainActor.run {
                scanProgress = Double(index) / Double(imageFiles.count)
            }
            
            do {
                let filePath = fileURL.path
                let fileHash = try getFileHash(filePath: filePath)
                
                if existingHashes.contains(fileHash) {
                    stats.existingFiles += 1
                    continue
                }
                
                // Get file attributes
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
                let fileSize = resourceValues.fileSize ?? 0
                let createdAt = resourceValues.creationDate ?? Date()
                let modifiedAt = resourceValues.contentModificationDate ?? Date()
                
                // Get image dimensions
                let (width, height) = getImageDimensions(filePath: filePath)
                
                // Insert into database (without AI analysis for now)
                let filename = fileURL.lastPathComponent
                
                // Check for duplicate filename first (INSERT OR IGNORE won't work if hash exists but filename different)
                let existing = db.query("SELECT id FROM screenshots WHERE file_hash = ? OR filename = ?", parameters: [fileHash, filename])
                if !existing.isEmpty {
                    stats.existingFiles += 1
                    continue
                }
                
                let success = db.execute("""
                    INSERT INTO screenshots 
                    (filename, filepath, file_hash, file_size, created_at, modified_at, width, height)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, parameters: [
                    filename,
                    filePath,
                    fileHash,
                    fileSize,
                    Database.dateToString(createdAt),
                    Database.dateToString(modifiedAt),
                    width ?? 0,
                    height ?? 0
                ])
                
                if success {
                    stats.newFiles += 1
                    print("✅ Added: \(filename) (\(fileSize) bytes)")
                } else {
                    stats.errors += 1
                    print("⚠️ Failed to insert: \(filename)")
                }
            } catch {
                stats.errors += 1
                print("❌ Error processing \(fileURL.lastPathComponent): \(error)")
            }
        }
        
        await MainActor.run {
            scanProgress = 1.0
        }
        
        print("✅ Scan complete: \(stats)")
        return stats
    }
    
    private func getFileHash(filePath: String) throws -> String {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let hash = SHA256.hash(data: fileData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func getImageDimensions(filePath: String) -> (Int?, Int?) {
        guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: filePath) as CFURL, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = imageProperties[kCGImagePropertyPixelWidth] as? Int,
              let height = imageProperties[kCGImagePropertyPixelHeight] as? Int else {
            return (nil, nil)
        }
        return (width, height)
    }
}

struct ScanResult {
    let totalFiles: Int
    var newFiles: Int
    var existingFiles: Int
    var errors: Int
}

