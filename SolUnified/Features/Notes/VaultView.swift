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
    @FocusState private var isViewFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            VaultFileBrowser(
                vaultPath: NSHomeDirectory() + "/Documents",
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
            .keyboardShortcut("b", modifiers: .command)
            .opacity(0)
            .allowsHitTesting(false)
        )
    }
}
