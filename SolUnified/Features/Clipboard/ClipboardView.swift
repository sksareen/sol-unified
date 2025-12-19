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
                        }
                    }
                }
                .background(Color.brutalistBgPrimary)
            }
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
                    
                    Text(formatDate(item.createdAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
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

