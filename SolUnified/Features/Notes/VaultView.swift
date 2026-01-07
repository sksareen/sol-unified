//
//  VaultView.swift
//  SolUnified
//
//  Vault view for browsing markdown files
//

import SwiftUI

class VaultViewState: ObservableObject {
    static let shared = VaultViewState()
    @Published var selectedFile: URL?
    
    private init() {}
}

struct VaultView: View {
    @StateObject private var state = VaultViewState.shared
    @ObservedObject private var settings = AppSettings.shared
    @FocusState private var isViewFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            VaultFileBrowser(
                vaultPath: settings.vaultRootDirectory,
                selectedFile: $state.selectedFile
            )
            
            WYSIWYGMarkdownEditor(fileURL: $state.selectedFile)
        }
        .background(Color.brutalistBgPrimary)
        .focused($isViewFocused)
        .onAppear {
            isViewFocused = true
        }
        .overlay(
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleVaultSidebar"), object: nil)
            }) {
                EmptyView()
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .opacity(0)
            .allowsHitTesting(false)
        )
        // Hidden button for opening today's note (Cmd+T)
        .overlay(
            Button(action: {
                openTodaysNote()
            }) {
                EmptyView()
            }
            .keyboardShortcut("t", modifiers: [.command])
            .opacity(0)
            .allowsHitTesting(false)
        )
    }
    
    private func openTodaysNote() {
        let dailyNoteURL = DailyNoteManager.shared.getOrCreateTodaysNote(
            vaultRoot: settings.vaultRootDirectory,
            journalFolder: settings.dailyNoteFolder,
            dateFormat: settings.dailyNoteDateFormat,
            template: settings.dailyNoteTemplate
        )
        
        if let url = dailyNoteURL {
            // Trigger file list refresh
            NotificationCenter.default.post(name: NSNotification.Name("RefreshVaultFiles"), object: nil)
            // Select the daily note
            state.selectedFile = url
        }
    }
}
