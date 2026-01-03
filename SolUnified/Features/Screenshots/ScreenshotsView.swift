//
//  ScreenshotsView.swift
//  SolUnified
//
//  Native screenshot organizer view
//

import SwiftUI
import AppKit

struct ScreenshotsView: View {
    @ObservedObject var store = ScreenshotsStore.shared
    @ObservedObject var scanner = ScreenshotScanner.shared
    @ObservedObject var analyzer = ScreenshotAnalyzer.shared
    @State private var searchText = ""
    @State private var selectedScreenshot: Screenshot?
    @State private var selectedId: Screenshot.ID?
    @State private var showingStats = false
    @State private var scanMessage = ""
    @State private var isLoading = false
    @State private var newScreenshotNotification: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SCREENSHOTS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let notification = newScreenshotNotification {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9))
                        Text(notification.uppercased())
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.green)
                    .padding(.trailing, 8)
                } else if !scanMessage.isEmpty {
                    Text(scanMessage.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.brutalistAccent)
                        .padding(.trailing, 8)
                }
                
                Button(action: {
                    store.getStats()
                    showingStats = true
                }) {
                    Label("STATS", systemImage: "chart.bar.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(BrutalistSecondaryButtonStyle())
            }
            .padding(16)
            .background(
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.brutalistTextMuted)
                
                TextField("Search screenshots...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: Typography.bodySize))
                    .foregroundColor(Color.brutalistTextPrimary)
                    .onChange(of: searchText) { _ in
                        store.loadScreenshots(search: searchText.isEmpty ? nil : searchText)
                    }
            }
            .padding(Spacing.md)
            .background(Color.brutalistBgSecondary)
            .cornerRadius(BorderRadius.sm)
            .padding(Spacing.lg)
            
            // Grid
            if scanner.isScanning {
                VStack(spacing: Spacing.md) {
                    ProgressView(value: scanner.scanProgress)
                        .progressViewStyle(.linear)
                    Text("Scanning screenshots...")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                    Text("\(Int(scanner.scanProgress * 100))%")
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                }
                .padding(Spacing.xl)
            } else if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .padding(Spacing.xl)
            } else if store.screenshots.isEmpty {
                VStack(spacing: Spacing.md) {
                    Text("No screenshots found")
                        .font(.system(size: Typography.headingSize))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("Screenshots are auto-captured when they appear in your folder")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                    
                    Text("Folder: \(AppSettings.shared.screenshotsDirectory)")
                        .font(.system(size: Typography.smallSize, design: .monospaced))
                        .foregroundColor(Color.brutalistTextMuted)
                        .padding(.top, Spacing.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(store.screenshots, selection: $selectedId) {
                    TableColumn("Preview") { screenshot in
                        if let nsImage = NSImage(contentsOfFile: screenshot.filepath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 40)
                                .cornerRadius(4)
                                .padding(.vertical, 2)
                        } else {
                            Rectangle()
                                .fill(Color.brutalistBgTertiary)
                                .frame(width: 60, height: 40)
                                .cornerRadius(4)
                                .padding(.vertical, 2)
                        }
                    }
                    .width(60)
                    
                    TableColumn("Name", value: \.filename)
                    
                    TableColumn("Source") { screenshot in
                        VStack(alignment: .leading, spacing: 2) {
                            if let appName = screenshot.sourceAppName {
                                Text(appName)
                                    .font(.system(size: Typography.bodySize, weight: .medium))
                                    .foregroundColor(Color.brutalistAccent)
                            } else {
                                Text("-")
                                    .font(.system(size: Typography.bodySize))
                                    .foregroundColor(Color.brutalistTextMuted)
                            }
                            if let windowTitle = screenshot.sourceWindowTitle, !windowTitle.isEmpty {
                                Text(windowTitle)
                                    .font(.system(size: Typography.smallSize))
                                    .foregroundColor(Color.brutalistTextMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    TableColumn("Tags") { screenshot in
                        Text(screenshot.aiTags ?? "-")
                            .font(.system(size: Typography.smallSize))
                            .foregroundColor(Color.brutalistTextMuted)
                    }
                    
                    TableColumn("Created") { screenshot in
                        Text(screenshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: Typography.smallSize))
                    }
                }
                .onChange(of: selectedId) { newId in
                    if let id = newId, let screenshot = store.screenshots.first(where: { $0.id == id }) {
                        selectedScreenshot = screenshot
                        // Deselect to allow clicking the same item again
                        selectedId = nil
                    }
                }
            }
        }
        .onAppear {
            loadScreenshots()
        }
        .onChange(of: scanner.lastNewScreenshot?.filename) { newFilename in
            // Auto-refresh when a new screenshot is detected
            if let filename = newFilename {
                newScreenshotNotification = "New: \(filename)"
                store.loadScreenshots(search: searchText.isEmpty ? nil : searchText)
                
                // Clear notification after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    newScreenshotNotification = nil
                }
            }
        }
        .sheet(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(screenshot: screenshot)
        }
        .sheet(isPresented: $showingStats) {
            if let stats = store.stats {
                StatsView(stats: stats)
            } else {
                EmptyView()
            }
        }
    }
    
    private func loadScreenshots() {
        isLoading = true
        store.loadScreenshots()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isLoading = false
        }
    }
    
    private func scanDirectory() async {
        scanMessage = ""
        let screenshotsDir = AppSettings.shared.screenshotsDirectory
        print("🔍 Scanning directory: \(screenshotsDir)")
        
        do {
            let result = try await scanner.scanDirectory(screenshotsDir)
            await MainActor.run {
                scanMessage = "Scanned: \(result.newFiles) new, \(result.existingFiles) existing"
                print("✅ Scan complete: \(result.totalFiles) files, \(result.newFiles) new, \(result.existingFiles) existing, \(result.errors) errors")
                
                // Reload screenshots after scan
                store.loadScreenshots()
                
                // Clear message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    scanMessage = ""
                }
            }
        } catch {
            await MainActor.run {
                scanMessage = "Error: \(error.localizedDescription)"
                print("❌ Scan error: \(error)")
                
                // Clear error message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    scanMessage = ""
                }
            }
        }
    }
}

struct ScreenshotDetailView: View {
    let screenshot: Screenshot
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SCREENSHOT DETAILS")
                    .font(.system(size: Typography.headingSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(BrutalistSecondaryButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Image
                    if let nsImage = NSImage(contentsOfFile: screenshot.filepath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(BorderRadius.md)
                    } else {
                        Rectangle()
                            .fill(Color.brutalistBgTertiary)
                            .frame(height: 400)
                            .overlay(
                                Text("Image not found")
                                    .font(.system(size: Typography.bodySize))
                                    .foregroundColor(Color.brutalistTextMuted)
                            )
                            .cornerRadius(BorderRadius.md)
                    }
                    
                    // Provenance Info (if available)
                    if screenshot.sourceAppName != nil || screenshot.sourceWindowTitle != nil {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("CAPTURED FROM")
                                .font(.system(size: Typography.smallSize, weight: .semibold))
                                .foregroundColor(Color.brutalistTextMuted)
                            
                            HStack(spacing: Spacing.md) {
                                if let appName = screenshot.sourceAppName {
                                    HStack(spacing: 4) {
                                        Image(systemName: "app.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.brutalistAccent)
                                        Text(appName)
                                            .font(.system(size: Typography.bodySize, weight: .medium))
                                            .foregroundColor(Color.brutalistTextPrimary)
                                    }
                                }
                                
                                if let windowTitle = screenshot.sourceWindowTitle, !windowTitle.isEmpty {
                                    Text("•")
                                        .foregroundColor(Color.brutalistTextMuted)
                                    Text(windowTitle)
                                        .font(.system(size: Typography.bodySize))
                                        .foregroundColor(Color.brutalistTextSecondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.brutalistAccent.opacity(0.1))
                        .cornerRadius(BorderRadius.sm)
                    }
                    
                    // Details
                    DetailRow(label: "Filename", value: screenshot.filename)
                    DetailRow(label: "Full Path", value: screenshot.filepath)
                    DetailRow(label: "Size", value: formatFileSize(screenshot.fileSize))
                    DetailRow(label: "Dimensions", value: "\(screenshot.width) × \(screenshot.height)")
                    
                    if let description = screenshot.aiDescription {
                        DetailRow(label: "Description", value: description)
                    }
                    
                    if let tags = screenshot.aiTags {
                        DetailRow(label: "Tags", value: tags)
                    }
                    
                    if let text = screenshot.aiTextContent, !text.isEmpty {
                        DetailRow(label: "Extracted Text", value: text)
                    }
                }
                .padding(Spacing.lg)
            }
        }
        .frame(width: 700, height: 600)
        .background(Color.brutalistBgPrimary)
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        if mb > 1 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.2f KB", kb)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased())
                .font(.system(size: Typography.smallSize, weight: .semibold))
                .foregroundColor(Color.brutalistTextMuted)
            
            Text(value)
                .font(.system(size: Typography.bodySize))
                .foregroundColor(Color.brutalistTextPrimary)
                .textSelection(.enabled)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.sm)
    }
}

struct StatsView: View {
    let stats: ScreenshotStats
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("STATISTICS")
                    .font(.system(size: Typography.headingSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(BrutalistSecondaryButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    StatCard(label: "Total Screenshots", value: "\(stats.totalScreenshots)")
                    StatCard(label: "Total Size", value: String(format: "%.2f MB", stats.totalSizeMB))
                    
                    if !stats.topTags.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("TOP TAGS")
                                .font(.system(size: Typography.bodySize, weight: .semibold))
                                .foregroundColor(Color.brutalistTextPrimary)
                            
                            ForEach(stats.topTags, id: \.tag) { tagCount in
                                HStack {
                                    Text(tagCount.tag)
                                        .font(.system(size: Typography.bodySize))
                                        .foregroundColor(Color.brutalistTextSecondary)
                                    
                                    Spacer()
                                    
                                    Text("\(tagCount.count)")
                                        .font(.system(size: Typography.bodySize, weight: .semibold))
                                        .foregroundColor(Color.brutalistTextPrimary)
                                }
                                .padding(Spacing.sm)
                                .background(Color.brutalistBgSecondary)
                                .cornerRadius(BorderRadius.sm)
                            }
                        }
                        .padding(Spacing.lg)
                        .brutalistCard()
                    }
                }
                .padding(Spacing.lg)
            }
        }
        .frame(width: 500, height: 600)
        .background(Color.brutalistBgPrimary)
    }
}

struct StatCard: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label.uppercased())
                .font(.system(size: Typography.smallSize, weight: .semibold))
                .foregroundColor(Color.brutalistTextMuted)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.brutalistTextPrimary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalistCard()
    }
}

