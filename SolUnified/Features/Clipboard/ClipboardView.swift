//
//  ClipboardView.swift
//  SolUnified
//
//  Clipboard history display
//

import SwiftUI
import AppKit

struct ClipboardView: View {
    @ObservedObject var store = ClipboardStore.shared
    @State private var searchQuery = ""
    @State private var copiedItemId: Int?
    @State private var selectedItem: ClipboardItem?
    
    var filteredItems: [ClipboardItem] {
        if searchQuery.isEmpty {
            return store.items
        }
        return store.searchHistory(query: searchQuery)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("CLIPBOARD")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        InternalAppTracker.shared.trackClipboardClear()
                        _ = store.clearHistory()
                    }) {
                        Text("CLEAR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.brutalistAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brutalistAccent.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    TextField("Search clipboard...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                        .onChange(of: searchQuery) { newValue in
                            if !newValue.isEmpty {
                                InternalAppTracker.shared.trackClipboardSearch(query: newValue)
                            }
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.brutalistBgTertiary)
                .cornerRadius(6)
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
            
            // Clipboard items
            if filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.2))
                    Text("No history")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Copy something to see it here")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brutalistBgPrimary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems) { item in
                            ClipboardItemCard(
                                item: item,
                                isCopied: copiedItemId == item.id
                            )
                            .onTapGesture {
                                if store.copyToPasteboard(item) {
                                    let preview = item.contentPreview ?? item.contentText ?? "Unknown"
                                    InternalAppTracker.shared.trackClipboardPaste(preview: preview)
                                    copiedItemId = item.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copiedItemId = nil
                                    }
                                }
                            }
                            .contextMenu {
                                Button {
                                    selectedItem = item
                                } label: {
                                    Label("View Details", systemImage: "info.circle")
                                }
                                
                                Button {
                                    if store.copyToPasteboard(item) {
                                        copiedItemId = item.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            copiedItemId = nil
                                        }
                                    }
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    // Delete functionality could be added here
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .background(Color.brutalistBgPrimary)
            }
        }
        .onAppear {
            // Refresh history when view appears
            store.loadHistory()
        }
        .sheet(item: $selectedItem) { item in
            ClipboardItemDetailView(item: item)
        }
    }
}

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let isCopied: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Content Icon/Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.brutalistBgSecondary)
                    .frame(width: 44, height: 44)
                
                if item.contentType == .image, let path = item.filePath, let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(Color.brutalistAccent.opacity(0.7))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let preview = item.contentPreview {
                    Text(preview)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary.opacity(0.9))
                        .lineLimit(2)
                }
                
                HStack(spacing: 6) {
                    Text(item.contentType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.3))
                    
                    // Source app context
                    if let appName = item.sourceAppName {
                        Text(appName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.brutalistAccent.opacity(0.8))
                        
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    
                    Text(formatDate(item.createdAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                
                // Window title (if available and different from app name)
                if let windowTitle = item.sourceWindowTitle, !windowTitle.isEmpty {
                    Text(windowTitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            if isCopied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.brutalistAccent)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCopied ? Color.brutalistAccent.opacity(0.05) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.brutalistBorder.opacity(0.5)),
            alignment: .bottom
        )
    }
    
    private var iconName: String {
        switch item.contentType {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        case .file:
            return "doc"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Clipboard Item Detail View

struct ClipboardItemDetailView: View {
    let item: ClipboardItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CLIPBOARD ITEM")
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
                    // Content Preview
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("CONTENT")
                            .font(.system(size: Typography.smallSize, weight: .semibold))
                            .foregroundColor(Color.brutalistTextMuted)
                        
                        if item.contentType == .image, let path = item.filePath, let nsImage = NSImage(contentsOfFile: path) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(BorderRadius.md)
                        } else if let text = item.contentText {
                            Text(text)
                                .font(.system(size: Typography.bodySize, design: .monospaced))
                                .foregroundColor(Color.brutalistTextPrimary)
                                .textSelection(.enabled)
                                .padding(Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.brutalistBgTertiary)
                                .cornerRadius(BorderRadius.sm)
                        } else if let preview = item.contentPreview {
                            Text(preview)
                                .font(.system(size: Typography.bodySize))
                                .foregroundColor(Color.brutalistTextPrimary)
                                .textSelection(.enabled)
                                .padding(Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.brutalistBgTertiary)
                                .cornerRadius(BorderRadius.sm)
                        }
                    }
                    
                    // Source Info (Provenance)
                    if item.sourceAppName != nil || item.sourceWindowTitle != nil {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("COPIED FROM")
                                .font(.system(size: Typography.smallSize, weight: .semibold))
                                .foregroundColor(Color.brutalistTextMuted)
                            
                            HStack(spacing: Spacing.md) {
                                if let appName = item.sourceAppName {
                                    HStack(spacing: 4) {
                                        Image(systemName: "app.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.brutalistAccent)
                                        Text(appName)
                                            .font(.system(size: Typography.bodySize, weight: .medium))
                                            .foregroundColor(Color.brutalistTextPrimary)
                                    }
                                }
                                
                                if let windowTitle = item.sourceWindowTitle, !windowTitle.isEmpty {
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
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("METADATA")
                            .font(.system(size: Typography.smallSize, weight: .semibold))
                            .foregroundColor(Color.brutalistTextMuted)
                        
                        MetadataRow(label: "Type", value: item.contentType.rawValue.capitalized)
                        MetadataRow(label: "Copied", value: formatFullDate(item.createdAt))
                        
                        if let filePath = item.filePath {
                            MetadataRow(label: "File Path", value: filePath)
                        }
                        
                        if let bundleId = item.sourceAppBundleId {
                            MetadataRow(label: "Bundle ID", value: bundleId)
                        }
                        
                        MetadataRow(label: "Hash", value: String(item.contentHash.prefix(16)) + "...")
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brutalistBgSecondary)
                    .cornerRadius(BorderRadius.sm)
                }
                .padding(Spacing.lg)
            }
        }
        .frame(width: 550, height: 500)
        .background(Color.brutalistBgPrimary)
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: Typography.bodySize, weight: .medium))
                .foregroundColor(Color.brutalistTextSecondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: Typography.bodySize))
                .foregroundColor(Color.brutalistTextPrimary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

