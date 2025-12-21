//
//  TerminalView.swift
//  SolUnified
//
//  Terminal emulator using SwiftTerm
//

import SwiftUI
import SwiftTerm

struct TerminalView: View {
    @StateObject private var terminalStore = TerminalStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("TERMINAL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                Button(action: {
                    terminalStore.clearTerminal()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Clear Terminal")
                
                Button(action: {
                    terminalStore.createNewTerminal()
                }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("New Terminal")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            TerminalViewWrapper(terminal: terminalStore.terminal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}

struct TerminalViewWrapper: NSViewRepresentable {
    let terminal: LocalProcessTerminalView
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        return terminal
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
    }
}

class TerminalStore: ObservableObject {
    static let shared = TerminalStore()
    
    @Published var terminal: LocalProcessTerminalView
    
    private init() {
        terminal = LocalProcessTerminalView(frame: .zero)
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminal.nativeForegroundColor = NSColor.white
        terminal.nativeBackgroundColor = NSColor.black
        terminal.configureNativeColors()
        
        startShell()
    }
    
    func startShell() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        terminal.startProcess(executable: shell, args: ["-l"])
    }
    
    func clearTerminal() {
        terminal.send(txt: "clear\n")
    }
    
    func createNewTerminal() {
        terminal.send(txt: "exit\n")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startShell()
        }
    }
}
