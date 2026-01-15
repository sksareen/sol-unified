//
//  HUDView.swift
//  SolUnified
//
//  The "Command Line for Life" - a minimalist input bar for setting objectives.
//  Triggered by Opt+P. Dark mode, Spotlight-style but thinner.
//

import SwiftUI

struct HUDView: View {
    @ObservedObject var objectiveStore = ObjectiveStore.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Input bar
            HStack(spacing: 12) {
                // Current objective indicator
                if objectiveStore.currentObjective != nil {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }

                // Text input
                TextField("What are you working on?", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .light, design: .default))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        submitObjective()
                    }

                // Duration indicator (if objective active)
                if let objective = objectiveStore.currentObjective {
                    Text(objective.formattedDuration)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Keyboard hint
                Text("↵")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.9))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            // Current objective display (below input, subtle)
            if let objective = objectiveStore.currentObjective {
                HStack {
                    Text("Currently:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Text(objective.text)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    Spacer()

                    // Complete button
                    Button(action: {
                        objectiveStore.completeObjective()
                        onDismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    // Cancel button
                    Button(action: {
                        objectiveStore.abandonObjective()
                        onDismiss()
                    }) {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .padding(20)
        .frame(width: 600)
        .onAppear {
            isInputFocused = true
            // Pre-fill with current objective if editing
            if let current = objectiveStore.currentObjective {
                inputText = current.text
            }
        }
        .onExitCommand {
            onDismiss()
        }
    }

    private func submitObjective() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onDismiss()
            return
        }

        objectiveStore.setObjective(trimmed)
        inputText = ""
        onDismiss()
    }
}

// MARK: - HUD Window Controller

class HUDWindowController: NSObject {
    static let shared = HUDWindowController()

    private var hudWindow: NSWindow?
    private var isVisible = false

    private override init() {
        super.init()
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard !isVisible else { return }

        // Create window if needed
        if hudWindow == nil {
            createWindow()
        }

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth: CGFloat = 640
            let windowHeight: CGFloat = 120

            let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
            let y = screenFrame.origin.y + screenFrame.height - windowHeight - 100 // 100px from top

            hudWindow?.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }

        hudWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }

    func hide() {
        hudWindow?.orderOut(nil)
        isVisible = false
    }

    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView:
            HUDView(onDismiss: { [weak self] in
                self?.hide()
            })
            .preferredColorScheme(.dark)
        )

        window.contentView = hostingView

        hudWindow = window
    }
}

// MARK: - Preview

#Preview {
    HUDView(onDismiss: {})
        .background(Color.gray)
        .preferredColorScheme(.dark)
}
