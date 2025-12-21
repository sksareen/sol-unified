import SwiftUI

struct AgentContextView: View {
    @StateObject private var store = AgentContextStore()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar: All 4 Agents
            HStack(spacing: 0) {
                if let state = store.agentState {
                    // Devon
                    if let devon = state.active_agents["devon"] {
                        CompactAgentStatus(
                            name: "DEVON",
                            role: "Product",
                            color: Color(hex: "F97316"),
                            status: devon
                        )
                    }
                    
                    // Josh
                    if let josh = state.active_agents["josh"] {
                        CompactAgentStatus(
                            name: "JOSH",
                            role: "CEO",
                            color: Color(hex: "10B981"),
                            status: josh
                        )
                    }
                    
                    // Gunter
                    if let gunter = state.active_agents["gunter"] {
                        CompactAgentStatus(
                            name: "GUNTER",
                            role: "Research",
                            color: Color(hex: "3B82F6"),
                            status: gunter
                        )
                    }
                    
                    // Kevin
                    if let kevin = state.active_agents["kevin"] {
                        CompactAgentStatus(
                            name: "KEVIN",
                            role: "AI/ML",
                            color: Color(hex: "8B5CF6"),
                            status: kevin
                        )
                    }
                } else {
                    Text("Loading agents...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
                
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
                    .frame(width: 50)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
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
            
            // Main Content: Message Log
            MessageLogView(messages: store.messages)
                .frame(maxHeight: .infinity)
            
            // Bottom Bar: Stats
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Last sync: \(formatTime(store.lastUpdated))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("\(store.messages.count) messages")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { store.refreshMemory() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                        Text("Update Memory")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color.brutalistAccent)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                VisualEffectView(material: .contentBackground, blendingMode: .withinWindow)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .top
            )
        }
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
    let status: AgentStatus
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.brutalistBgPrimary, lineWidth: 1.5)
                    )
                    .offset(x: 9, y: 9)
                
                Text(String(name.prefix(1)))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 10, weight: .black))
                        .tracking(0.3)
                    
                    Text(status.status.uppercased())
                        .font(.system(size: 7, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.brutalistBgTertiary)
                        .cornerRadius(2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Text(status.current_focus)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
    
    private var statusColor: Color {
        switch status.status.lowercased() {
        case "active": return Color.green
        case "standby": return Color.yellow
        case "offline": return Color.secondary
        default: return Color.secondary
        }
    }
}

#Preview {
    AgentContextView()
}
