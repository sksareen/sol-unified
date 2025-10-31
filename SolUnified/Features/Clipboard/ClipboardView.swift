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
    
    var filteredItems: [ClipboardItem] {
        if searchQuery.isEmpty {
            return store.items
        }
        return store.searchHistory(query: searchQuery)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.md) {
                HStack {
                    Text("CLIPBOARD HISTORY")
                        .font(.system(size: Typography.headingSize, weight: .semibold))
                        .foregroundColor(Color.brutalistTextPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        _ = store.clearHistory()
                    }) {
                        Text("CLEAR ALL")
                            .font(.system(size: Typography.bodySize, weight: .medium))
                    }
                    .buttonStyle(BrutalistSecondaryButtonStyle())
                }
                
                // Search bar
                TextField("Search clipboard...", text: $searchQuery)
                    .textFieldStyle(BrutalistTextFieldStyle())
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Clipboard items
            if filteredItems.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Text("No clipboard history")
                        .font(.system(size: Typography.headingSize))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("Copy something to see it here")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(filteredItems) { item in
                            ClipboardItemCard(
                                item: item,
                                isCopied: copiedItemId == item.id
                            )
                            .onTapGesture {
                                if store.copyToPasteboard(item) {
                                    copiedItemId = item.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copiedItemId = nil
                                    }
                                }
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
        }
    }
}

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let isCopied: Bool
    @State private var thumbnail: NSImage?
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Icon or Image Thumbnail
            if item.contentType == .image, let path = item.filePath, let image = NSImage(contentsOfFile: path) {
                // Show actual image thumbnail
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(BorderRadius.sm)
            } else {
                // Show icon for text/files
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(Color.brutalistAccent)
                    .frame(width: 60, height: 60)
            }
            
            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let preview = item.contentPreview {
                    Text(preview)
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextPrimary)
                        .lineLimit(3)
                }
                
                HStack {
                    Text(item.contentType.rawValue.uppercased())
                        .font(.system(size: Typography.smallSize, weight: .medium))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("•")
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text(formatDate(item.createdAt))
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                }
            }
            
            Spacer()
            
            // Copy indicator
            if isCopied {
                Text("COPIED")
                    .font(.system(size: Typography.smallSize, weight: .semibold))
                    .foregroundColor(Color.brutalistAccent)
            }
        }
        .padding(Spacing.lg)
        .background(isCopied ? Color.brutalistBgTertiary : Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.md)
                .stroke(isCopied ? Color.brutalistAccent : Color.brutalistBorder, lineWidth: isCopied ? 2 : 1)
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

