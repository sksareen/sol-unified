//
//  VaultFileBrowser.swift
//  SolUnified
//
//  File browser sidebar for markdown vault
//

import SwiftUI

class VaultFilesStore: ObservableObject {
    static let shared = VaultFilesStore()
    @Published var files: [MarkdownFile] = []
    @Published var hasLoaded = false
    @Published var expandedFolders: Set<String> = []
    @Published var isCollapsed: Bool = false
    
    private init() {}
}

struct VaultFileBrowser: View {
    let vaultPath: String
    @Binding var selectedFile: URL?
    @StateObject private var filesStore = VaultFilesStore.shared
    @State private var searchQuery: String = ""
    @FocusState private var isSearchFocused: Bool
    
    var filteredFiles: [MarkdownFile] {
        if searchQuery.isEmpty {
            return filesStore.files
        }
        return filesStore.files.filter { file in
            file.name.lowercased().contains(searchQuery.lowercased())
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if !filesStore.isCollapsed {
                VStack(spacing: 0) {
                    // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.system(size: 11))
                
                TextField("Search files...", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11))
                    .focused($isSearchFocused)
                    .onChange(of: searchQuery) { newValue in
                        if !newValue.isEmpty {
                            // Expand all folders when searching
                            filesStore.expandedFolders = Set(groupFilesByFolder(filteredFiles).map { $0.folder })
                        }
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.system(size: 11))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(8)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // File list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(groupFilesByFolder(filteredFiles)) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            // Folder header
                            Button(action: {
                                toggleFolder(group.folder)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: filesStore.expandedFolders.contains(group.folder) ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                    
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 11))
                                    
                                    Text(group.folder)
                                        .font(.system(size: 11, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    Text("\(group.files.count)")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .foregroundColor(.brutalistTextPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .background(Color.brutalistBgTertiary.opacity(0.5))
                            
                            // Files in folder
                            if filesStore.expandedFolders.contains(group.folder) {
                                ForEach(group.files) { file in
                                    FileRow(
                                        file: file,
                                        isSelected: selectedFile == file.url,
                                        onTap: {
                                            selectedFile = file.url
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Color.brutalistBgPrimary)
                }
                .frame(width: 250)
                .background(Color.brutalistBgPrimary)
            }
            
            // Collapse/Expand button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    filesStore.isCollapsed.toggle()
                }
            }) {
                Image(systemName: filesStore.isCollapsed ? "sidebar.left" : "sidebar.left.slash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.brutalistTextSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color.brutalistBgSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help(filesStore.isCollapsed ? "Show Sidebar" : "Hide Sidebar")
        }
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.brutalistBorder),
            alignment: .trailing
        )
        .onAppear {
            if !filesStore.hasLoaded {
                loadFiles()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusVaultSearch"))) { _ in
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleVaultSidebar"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                filesStore.isCollapsed.toggle()
            }
        }
    }
    
    private func loadFiles() {
        filesStore.hasLoaded = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: vaultPath),
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            
            var foundFiles: [MarkdownFile] = []
            
            for case let fileURL as URL in enumerator {
                let path = fileURL.path
                if path.contains("node_modules") || path.contains(".git") || path.contains(".obsidian") {
                    enumerator.skipDescendants()
                    continue
                }
                
                guard fileURL.pathExtension == "md" else { continue }
                
                let relativePath = fileURL.path.replacingOccurrences(of: vaultPath + "/", with: "")
                foundFiles.append(MarkdownFile(url: fileURL, relativePath: relativePath))
            }
            
            let sortedFiles = foundFiles.sorted { $0.relativePath < $1.relativePath }
            
            DispatchQueue.main.async {
                self.filesStore.files = sortedFiles
            }
        }
    }
    
    private func groupFilesByFolder(_ files: [MarkdownFile]) -> [FileGroup] {
        var groups: [String: [MarkdownFile]] = [:]
        
        for file in files {
            let components = file.relativePath.split(separator: "/")
            let folder = components.count > 1 ? String(components[0]) : "Root"
            
            if groups[folder] == nil {
                groups[folder] = []
            }
            groups[folder]?.append(file)
        }
        
        return groups.map { FileGroup(folder: $0.key, files: $0.value) }
            .sorted { $0.folder < $1.folder }
    }
    
    private func toggleFolder(_ folder: String) {
        if filesStore.expandedFolders.contains(folder) {
            filesStore.expandedFolders.remove(folder)
        } else {
            filesStore.expandedFolders.insert(folder)
        }
    }
}

struct FileRow: View {
    let file: MarkdownFile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Text(file.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .brutalistTextPrimary : .brutalistTextSecondary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isSelected ? Color.brutalistAccent.opacity(0.15) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MarkdownFile: Identifiable {
    let id = UUID()
    let url: URL
    let relativePath: String
    
    var name: String {
        url.lastPathComponent
    }
}

struct FileGroup: Identifiable {
    let id = UUID()
    let folder: String
    let files: [MarkdownFile]
}
