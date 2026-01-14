//
//  NotesView.swift
//  SolUnified
//
//  Main notes feature UI - Scratchpad + Vault browser
//

import SwiftUI

struct NotesView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedMode: NotesMode = .scratchpad
    @State private var selectedFile: URL?

    enum NotesMode: String, CaseIterable {
        case scratchpad = "SCRATCHPAD"
        case vault = "VAULT"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode Selector
            HStack(spacing: 4) {
                ForEach(NotesMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMode = mode
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: selectedMode == mode ? .bold : .medium))
                            .tracking(0.5)
                            .foregroundColor(selectedMode == mode ? .brutalistTextPrimary : .brutalistTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                ZStack {
                                    if selectedMode == mode {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.brutalistBgTertiary)
                                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Content
            Group {
                switch selectedMode {
                case .scratchpad:
                    ScratchpadView()
                case .vault:
                    HStack(spacing: 0) {
                        VaultFileBrowser(
                            vaultPath: settings.vaultRootDirectory,
                            selectedFile: $selectedFile
                        )
                        .id(settings.vaultRootDirectory) // Force recreation when path changes

                        WYSIWYGMarkdownEditor(fileURL: $selectedFile)
                    }
                }
            }
        }
        .background(Color.brutalistBgPrimary)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusVaultSearch"))) { _ in
            if selectedMode != .vault {
                selectedMode = .vault
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleSidebar"))) { _ in
            NotificationCenter.default.post(name: NSNotification.Name("ToggleVaultSidebar"), object: nil)
        }
    }
}

