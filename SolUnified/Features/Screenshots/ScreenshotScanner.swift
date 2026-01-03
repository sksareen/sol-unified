//
//  ScreenshotScanner.swift
//  SolUnified
//
//  Native screenshot file scanner and analyzer with auto-detection
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
    @Published var lastNewScreenshot: Screenshot?
    
    private let db = Database.shared
    private var directoryMonitor: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    
    // Track the last known state for detecting new files quickly
    private var lastKnownFileCount: Int = 0
    private var lastKnownFiles: Set<String> = []
    
    // Store recent app context for provenance tracking
    // When a screenshot appears, we capture what app was active just before
    private var recentAppContext: (bundleId: String?, appName: String?, windowTitle: String?) = (nil, nil, nil)
    private var contextUpdateTimer: Timer?
    
    private init() {
        startContextTracking()
    }
    
    /// Track the current active app context periodically
    /// This is needed because when a screenshot appears, the app that was being screenshotted
    /// is usually NOT the frontmost app at detection time (macOS screen capture is active)
    private func startContextTracking() {
        contextUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Don't update context if a system app (screenshot utility) is frontmost
            let currentApp = ActivityMonitor.shared.getCurrentApp()
            let bundleId = currentApp?.bundleIdentifier ?? ""
            
            // Skip system screenshot utilities
            let screenshotApps = ["com.apple.screencaptureui", "com.apple.screenshot", "com.apple.screencapture"]
            if screenshotApps.contains(bundleId) {
                return
            }
            
            self.recentAppContext = (
                bundleId: currentApp?.bundleIdentifier,
                appName: currentApp?.localizedName,
                windowTitle: ActivityMonitor.shared.getActiveWindowTitle()
            )
        }
    }
    
    func startMonitoring(directory: String) {
        stopMonitoring()
        
        let expandedPath = (directory as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        // Initialize known files set
        if let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            lastKnownFiles = Set(files.map { $0.lastPathComponent })
            lastKnownFileCount = files.count
        }
        
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            print("❌ Failed to open directory for monitoring: \(url.path)")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // Quick check for new files instead of full scan
            Task {
                // Small delay to let file finish writing
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await self.checkForNewFiles(directory: directory)
            }
        }
        
        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        
        source.resume()
        directoryMonitor = source
        print("📸 Started auto-monitoring screenshot directory: \(directory)")
        
        // Do an initial scan
        Task {
            _ = try? await scanDirectory(directory)
        }
    }
    
    func stopMonitoring() {
        directoryMonitor?.cancel()
        directoryMonitor = nil
        contextUpdateTimer?.invalidate()
        contextUpdateTimer = nil
    }
    
    /// Quick check for new files - more efficient than full scan
    private func checkForNewFiles(directory: String) async {
        let expandedPath = (directory as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "bmp"]
        let imageFiles = files.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        let currentFileNames = Set(imageFiles.map { $0.lastPathComponent })
        
        // Find new files
        let newFiles = currentFileNames.subtracting(lastKnownFiles)
        
        if !newFiles.isEmpty {
            print("📸 Detected \(newFiles.count) new screenshot(s)")
            
            // Capture the app context that was active just before the screenshot
            let capturedContext = recentAppContext
            
            for filename in newFiles {
                if let fileURL = imageFiles.first(where: { $0.lastPathComponent == filename }) {
                    await processNewScreenshot(fileURL: fileURL, context: capturedContext)
                }
            }
            
            // Update known files
            lastKnownFiles = currentFileNames
            lastKnownFileCount = imageFiles.count
            
            // Notify store to reload
            await MainActor.run {
                ScreenshotsStore.shared.loadScreenshots()
            }
        }
    }
    
    /// Process a single new screenshot with provenance metadata
    private func processNewScreenshot(fileURL: URL, context: (bundleId: String?, appName: String?, windowTitle: String?)) async {
        do {
            let filePath = fileURL.path
            let fileHash = try getFileHash(filePath: filePath)
            
            // Check if already exists
            let existing = db.query("SELECT id FROM screenshots WHERE file_hash = ? OR filename = ?", parameters: [fileHash, fileURL.lastPathComponent])
            if !existing.isEmpty {
                return
            }
            
            // Get file attributes
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
            let fileSize = resourceValues.fileSize ?? 0
            let createdAt = resourceValues.creationDate ?? Date()
            let modifiedAt = resourceValues.contentModificationDate ?? Date()
            
            // Get image dimensions
            let (width, height) = getImageDimensions(filePath: filePath)
            
            let filename = fileURL.lastPathComponent
            
            // Insert with provenance metadata
            let success = db.execute("""
                INSERT INTO screenshots 
                (filename, filepath, file_hash, file_size, created_at, modified_at, width, height, source_app_bundle_id, source_app_name, source_window_title)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                filename,
                filePath,
                fileHash,
                fileSize,
                Database.dateToString(createdAt),
                Database.dateToString(modifiedAt),
                width ?? 0,
                height ?? 0,
                context.bundleId ?? NSNull(),
                context.appName ?? NSNull(),
                context.windowTitle ?? NSNull()
            ])
            
            if success {
                print("📸 Auto-captured: \(filename) from \(context.appName ?? "unknown") - \(context.windowTitle ?? "")")
                
                // Link to context graph
                ContextGraphManager.shared.linkScreenshot(filename: filename)
                
                // Update the published property for UI notification
                await MainActor.run {
                    self.lastNewScreenshot = Screenshot(
                        filename: filename,
                        filepath: filePath,
                        fileHash: fileHash,
                        fileSize: fileSize,
                        createdAt: createdAt,
                        modifiedAt: modifiedAt,
                        width: width ?? 0,
                        height: height ?? 0,
                        sourceAppBundleId: context.bundleId,
                        sourceAppName: context.appName,
                        sourceWindowTitle: context.windowTitle
                    )
                }
            }
        } catch {
            print("❌ Error processing new screenshot \(fileURL.lastPathComponent): \(error)")
        }
    }
    
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
                
                // Use recent app context for provenance (may be nil for bulk scans)
                let context = recentAppContext
                
                let success = db.execute("""
                    INSERT INTO screenshots 
                    (filename, filepath, file_hash, file_size, created_at, modified_at, width, height, source_app_bundle_id, source_app_name, source_window_title)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, parameters: [
                    filename,
                    filePath,
                    fileHash,
                    fileSize,
                    Database.dateToString(createdAt),
                    Database.dateToString(modifiedAt),
                    width ?? 0,
                    height ?? 0,
                    context.bundleId ?? NSNull(),
                    context.appName ?? NSNull(),
                    context.windowTitle ?? NSNull()
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
        
        // Notify store to reload
        await MainActor.run {
            ScreenshotsStore.shared.loadScreenshots()
        }
        
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

