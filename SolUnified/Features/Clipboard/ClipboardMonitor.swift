//
//  ClipboardMonitor.swift
//  SolUnified
//
//  Monitor NSPasteboard for changes
//

import Foundation
import AppKit

class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private let store = ClipboardStore.shared
    
    private init() {}
    
    func startMonitoring() {
        // Run on main thread to avoid threading issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.lastChangeCount = self.pasteboard.changeCount
            
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.checkForChanges()
                }
            }
            
            print("Clipboard monitoring started")
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        print("Clipboard monitoring stopped")
    }
    
    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        
        lastChangeCount = currentChangeCount
        processClipboardContent()
    }
    
    private func processClipboardContent() {
        // Check for text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let hash = ClipboardStore.hashContent(text)
            let preview = text.prefix(100).description
            
            let item = ClipboardItem(
                contentType: .text,
                contentText: text,
                contentPreview: preview,
                contentHash: hash,
                createdAt: Date()
            )
            
            _ = store.saveItem(item)
            InternalAppTracker.shared.trackClipboardCopy(preview: preview)
            return
        }
        
        // Check for image
        if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            saveImage(image)
            return
        }
        
        // Check for file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], let url = urls.first {
            let hash = ClipboardStore.hashContent(url.path)
            let preview = url.lastPathComponent
            
            let item = ClipboardItem(
                contentType: .file,
                contentPreview: preview,
                filePath: url.path,
                contentHash: hash,
                createdAt: Date()
            )
            
            _ = store.saveItem(item)
            InternalAppTracker.shared.trackClipboardCopy(preview: preview)
            return
        }
    }
    
    private func saveImage(_ image: NSImage) {
        // Save image to temporary location
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let clipboardDir = appSupport.appendingPathComponent("SolUnified/clipboard", isDirectory: true)
        
        try? fileManager.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        
        let filename = "clipboard_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = clipboardDir.appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            
            let hash = ClipboardStore.hashContent(fileURL.path)
            let item = ClipboardItem(
                contentType: .image,
                contentPreview: "Image",
                filePath: fileURL.path,
                contentHash: hash,
                createdAt: Date()
            )
            
            _ = store.saveItem(item)
            InternalAppTracker.shared.trackClipboardCopy(preview: "Image")
        } catch {
            print("Failed to save clipboard image: \(error)")
        }
    }
}

