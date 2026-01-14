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
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var expandedFolders: Set<String> = []
    @Published var isCollapsed: Bool = false
    @Published var errorMessage: String?

    // Cache management
    private var cachedVaultPath: String?
    private var cacheTime: Date?
    private let cacheExpirationSeconds: TimeInterval = 300 // 5 minutes

    private init() {}

    /// Check if the vault path is valid (exists and is a directory)
    func isValidVaultPath(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// Check if cache is valid for the given vault path
    func isCacheValid(for vaultPath: String) -> Bool {
        guard cachedVaultPath == vaultPath,
              let cacheTime = cacheTime,
              !files.isEmpty else {
            return false
        }
        return Date().timeIntervalSince(cacheTime) < cacheExpirationSeconds
    }

    /// Update cache metadata after loading
    func updateCache(for vaultPath: String) {
        cachedVaultPath = vaultPath
        cacheTime = Date()
    }

    /// Invalidate the cache to force a reload
    func invalidateCache() {
        cachedVaultPath = nil
        cacheTime = nil
    }
}

struct VaultFileBrowser: View {
    let vaultPath: String
    @Binding var selectedFile: URL?
    @ObservedObject private var filesStore = VaultFilesStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var searchQuery: String = ""
    @State private var showNewFilePopover: Bool = false
    @State private var newFileName: String = ""
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isNewFileFocused: Bool
    
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
                    // Action bar - Today's Note + New File
                    HStack(spacing: 6) {
                        // Today's Note button
                        Button(action: {
                            openTodaysNote()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text("Today")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.brutalistAccent.opacity(0.15))
                            .foregroundColor(.brutalistAccent)
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Open today's note (⌘T)")
                        
                        Spacer()

                        // Refresh button
                        Button(action: {
                            filesStore.invalidateCache()
                            loadFiles(forceRefresh: true)
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.brutalistTextSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Refresh files")

                        // New File button
                        Button(action: {
                            showNewFilePopover = true
                            newFileName = ""
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.brutalistTextSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("New file")
                        .popover(isPresented: $showNewFilePopover, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("New Note")
                                    .font(.system(size: 11, weight: .semibold))
                                
                                HStack {
                                    TextField("filename", text: $newFileName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(size: 11))
                                        .focused($isNewFileFocused)
                                        .onSubmit {
                                            createNewFile()
                                        }
                                    
                                    Text(".md")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Spacer()
                                    Button("Cancel") {
                                        showNewFilePopover = false
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    
                                    Button("Create") {
                                        createNewFile()
                                    }
                                    .buttonStyle(BorderedProminentButtonStyle())
                                    .disabled(newFileName.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                            .padding(12)
                            .frame(width: 220)
                            .onAppear {
                                isNewFileFocused = true
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.brutalistBgSecondary)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.brutalistBorder),
                        alignment: .bottom
                    )
                    
                    // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.system(size: settings.globalFontSize - 2))
                
                TextField("Search files...", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: settings.globalFontSize - 1))
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
                            .font(.system(size: settings.globalFontSize - 2))
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
            ZStack {
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
                                            .font(.system(size: settings.globalFontSize - 4, weight: .bold))
                                        
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: settings.globalFontSize - 1))
                                        
                                        Text(group.folder)
                                            .font(.system(size: settings.globalFontSize - 1, weight: .semibold))
                                        
                                        Spacer()
                                        
                                        Text("\(group.files.count)")
                                            .font(.system(size: settings.globalFontSize - 4, weight: .medium))
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
                
                if filesStore.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brutalistBgPrimary.opacity(0.8))
                }

                if let error = filesStore.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brutalistBgPrimary)
                }
            }
            .background(Color.brutalistBgPrimary)
                }
                .frame(width: 250)
                .background(Color.brutalistBgPrimary)
            }
            
            // Collapse/Expand button - Full Height
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    filesStore.isCollapsed.toggle()
                }
            }) {
                ZStack {
                    Color.brutalistBgSecondary
                    
                    VStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.brutalistTextSecondary)
                            .rotationEffect(.degrees(filesStore.isCollapsed ? 0 : 180))
                        Spacer()
                    }
                }
                .frame(width: 12)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            .help(filesStore.isCollapsed ? "Show Sidebar (⌘+Shift+B)" : "Hide Sidebar (⌘+Shift+B)")
        }
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.brutalistBorder),
            alignment: .trailing
        )
        .onAppear {
            print("📁 VaultFileBrowser onAppear - vaultPath: \(vaultPath)")
            print("📁 Cache valid: \(filesStore.isCacheValid(for: vaultPath)), files count: \(filesStore.files.count)")
            loadFiles()  // Uses cache if available
        }
        .onChange(of: vaultPath) { newPath in
            filesStore.invalidateCache()  // Path changed, invalidate cache
            loadFiles(forceRefresh: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusVaultSearch"))) { _ in
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleVaultSidebar"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                filesStore.isCollapsed.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshVaultFiles"))) { _ in
            filesStore.invalidateCache()
            loadFiles(forceRefresh: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenTodaysNote"))) { _ in
            openTodaysNote()
        }
    }
    
    private func openTodaysNote() {
        let dailyNoteURL = DailyNoteManager.shared.getOrCreateTodaysNote(
            vaultRoot: vaultPath,
            journalFolder: settings.dailyNoteFolder,
            dateFormat: settings.dailyNoteDateFormat,
            template: settings.dailyNoteTemplate
        )
        
        if let url = dailyNoteURL {
            // Refresh file list to include the new note
            loadFiles()
            // Select the daily note
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedFile = url
            }
        }
    }
    
    private func createNewFile() {
        guard !newFileName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let folderURL = URL(fileURLWithPath: vaultPath)
        if let url = DailyNoteManager.shared.createNewFile(at: folderURL, fileName: newFileName) {
            showNewFilePopover = false
            loadFiles()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedFile = url
            }
        }
    }
    
    private func loadFiles(forceRefresh: Bool = false) {
        // Validate vault path first
        guard filesStore.isValidVaultPath(vaultPath) else {
            print("📁 Invalid vault path: '\(vaultPath)'")
            filesStore.errorMessage = vaultPath.isEmpty
                ? "No vault folder selected. Go to Settings to choose one."
                : "Vault folder not found: \(vaultPath)"
            filesStore.files = []
            filesStore.isLoading = false
            return
        }

        // Clear any previous error
        filesStore.errorMessage = nil

        // Use cache if valid and not forcing refresh
        if !forceRefresh && filesStore.isCacheValid(for: vaultPath) {
            print("📁 Using cached vault files for \(vaultPath)")
            return
        }

        filesStore.isLoading = true
        filesStore.hasLoaded = true
        // Don't clear files - keep showing old content while loading

        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: self.vaultPath),
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                DispatchQueue.main.async {
                    self.filesStore.isLoading = false
                    self.filesStore.errorMessage = "Could not read vault folder"
                }
                return
            }
            
            var foundFiles: [MarkdownFile] = []
            var journalFiles: [MarkdownFile] = []
            
            // Directories to exclude for performance
            let excludedDirs = [
                "node_modules", ".git", ".obsidian", ".trash", ".build", ".swiftpm",
                "Library", "Applications", "System", "bin", "sbin", "usr",
                "DerivedData", "build", "Pods", "Carthage", "xcuserdata",
                "dist", "target", "vendor", "__pycache__", ".venv", "venv",
                ".next", ".nuxt", ".output", "coverage", ".nyc_output"
            ]
            
            for case let fileURL as URL in enumerator {
                let path = fileURL.path
                
                // Check exclusions
                var shouldSkip = false
                for excluded in excludedDirs {
                    if path.contains("/\(excluded)/") || path.hasSuffix("/\(excluded)") {
                        shouldSkip = true
                        break
                    }
                }
                
                if shouldSkip {
                    enumerator.skipDescendants()
                    continue
                }
                
                guard fileURL.pathExtension == "md" else { continue }
                
                let relativePath = fileURL.path.replacingOccurrences(of: vaultPath + "/", with: "")
                let file = MarkdownFile(url: fileURL, relativePath: relativePath)
                foundFiles.append(file)
                
                if relativePath.lowercased().hasPrefix("journal/") {
                    journalFiles.append(file)
                }
                
                // Limit total files to prevent UI freeze on huge folders
                if foundFiles.count > 5000 {
                    break
                }
            }
            
            let sortedFiles = foundFiles.sorted { $0.relativePath < $1.relativePath }
            
            DispatchQueue.main.async {
                self.filesStore.files = sortedFiles
                self.filesStore.isLoading = false
                self.filesStore.updateCache(for: self.vaultPath)
                print("📁 Loaded \(sortedFiles.count) files from \(self.vaultPath)")

                // Default to latest daily note
                if self.selectedFile == nil, let latestJournal = journalFiles.sorted(by: { $0.name > $1.name }).first {
                    self.selectedFile = latestJournal.url
                }
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
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: settings.globalFontSize - 3))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Text(file.name)
                    .font(.system(size: settings.globalFontSize - 1, weight: isSelected ? .semibold : .regular))
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
