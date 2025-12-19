import SwiftUI

struct AgentContextView: View {
    @StateObject private var store = AgentContextStore()
    @State private var messageText: String = ""
    @State private var selectedRecipient: String = "Both"
    
    let recipients = ["Both", "Josh", "Gunter"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar: Clean Agent Status
            HStack(spacing: 0) {
                // Josh
                CompactAgentStatus(
                    name: "JOSH",
                    role: "Product",
                    color: Color(hex: "F97316"),
                    context: store.joshContext
                )
                
                // Sync Control
                Button(action: { store.forceSync() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .rotationEffect(.degrees(store.isSyncing ? 360 : 0))
                            .animation(store.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.isSyncing)
                        
                        if !store.isSyncing {
                            Text(formatTime(store.lastUpdated))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                    .foregroundColor(store.isSyncing ? Color.brutalistAccent : .secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(store.isSyncing ? Color.brutalistAccent.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 4)
                
                // Gunter
                CompactAgentStatus(
                    name: "GUNTER",
                    role: "Research",
                    color: Color(hex: "3B82F6"),
                    context: store.researchContext
                )
            }
            .padding(.horizontal, 16)
            .frame(height: 72)
            .background(
                VisualEffectView(material: .contentBackground, blendingMode: .withinWindow)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Main Content: Bridge / Conversation
            AgentBridgeView(bridge: store.agentBridge)
                .frame(maxHeight: .infinity)
            
            // Bottom Bar: Chat Input
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Menu {
                        ForEach(recipients, id: \.self) { recipient in
                            Button(recipient) {
                                selectedRecipient = recipient
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedRecipient)
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brutalistBgTertiary)
                        .cornerRadius(4)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .fixedSize()
                    
                    TextField("Message to agents...", text: $messageText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                        .onSubmit {
                            sendMessage()
                        }
                    
                    HStack(spacing: 16) {
                        Button(action: { store.refreshMemory() }) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 16))
                                .foregroundColor(Color.brutalistAccent)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Update memory intelligence")
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundColor(messageText.isEmpty ? .secondary : Color.brutalistAccent)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(messageText.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    VisualEffectView(material: .contentBackground, blendingMode: .withinWindow)
                )
            }
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .top
            )
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        store.sendMessage(content: messageText, to: selectedRecipient)
        messageText = ""
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CompactAgentStatus: View {
    let name: String
    let role: String
    let color: Color
    let context: AgentContext?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.brutalistBgPrimary, lineWidth: 2)
                    )
                    .offset(x: 10, y: 10)
                
                Text(String(name.prefix(1)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 11, weight: .black))
                        .tracking(0.5)
                    
                    Text(context?.status ?? "OFFLINE")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.brutalistBgTertiary)
                        .cornerRadius(3)
                        .foregroundColor(.secondary)
                }
                
                if let mission = context?.mission {
                    Text(mission)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// Keep AgentColumn for reference or future use if needed, but it's not used in this layout
struct AgentColumn: View {
    let name: String
    let role: String
    let color: Color
    let context: AgentContext?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ... (original implementation)
            EmptyView()
        }
    }
}

