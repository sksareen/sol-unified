import SwiftUI

struct AgentContextView: View {
    @StateObject private var store = AgentContextStore()
    @State private var selectedAgent: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Agents")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                if store.isSyncing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                }
                
                Button(action: { store.forceSync() }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.brutalistAccent)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            VSplitView {
                // Agent List
                if let state = store.agentState {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if let mable = state.active_agents["mable"] {
                                AgentRow(name: "Mable", role: "Orchestrator", color: Color(hex: "EC4899"), status: mable, store: store, isSelected: selectedAgent == "mable")
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedAgent = selectedAgent == "mable" ? nil : "mable"
                                        }
                                    }
                            }
                            if let devon = state.active_agents["devon"] {
                                AgentRow(name: "Devon", role: "Product", color: Color(hex: "F97316"), status: devon, store: store, isSelected: selectedAgent == "devon")
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedAgent = selectedAgent == "devon" ? nil : "devon"
                                        }
                                    }
                            }
                            if let josh = state.active_agents["josh"] {
                                AgentRow(name: "Josh", role: "CEO", color: Color(hex: "10B981"), status: josh, store: store, isSelected: selectedAgent == "josh")
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedAgent = selectedAgent == "josh" ? nil : "josh"
                                        }
                                    }
                            }
                            if let gunter = state.active_agents["gunter"] {
                                AgentRow(name: "Gunter", role: "Research", color: Color(hex: "3B82F6"), status: gunter, store: store, isSelected: selectedAgent == "gunter")
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedAgent = selectedAgent == "gunter" ? nil : "gunter"
                                        }
                                    }
                            }
                            if let kevin = state.active_agents["kevin"] {
                                AgentRow(name: "Kevin", role: "AI/ML", color: Color(hex: "8B5CF6"), status: kevin, store: store, isSelected: selectedAgent == "kevin")
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedAgent = selectedAgent == "kevin" ? nil : "kevin"
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(minHeight: 200)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading agents...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.brutalistTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 200)
                }
                
                MessageLogView(messages: store.messages)
                    .frame(minHeight: 200)
            }
        }
        .background(Color.brutalistBgPrimary)
    }
}

struct AgentRow: View {
    let name: String
    let role: String
    let color: Color
    let status: AgentStatus
    @ObservedObject var store: AgentContextStore
    let isSelected: Bool
    @State private var isHovered = false
    
    var statusColor: Color {
        switch status.status.lowercased() {
        case "active": return Color(hex: "#34C759")
        case "standby": return Color(hex: "#FFCC00")
        case "offline": return Color.brutalistTextMuted
        default: return Color.brutalistTextMuted
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 20, height: 20)
                    
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 14))
                        .foregroundColor(Color.brutalistTextPrimary)
                    
                    if isSelected {
                        Text(status.current_focus)
                            .font(.system(size: 12))
                            .foregroundColor(Color.brutalistTextSecondary)
                            .padding(.top, 2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        
                        HStack(spacing: 8) {
                            Text(role)
                                .font(.system(size: 11))
                                .foregroundColor(Color.brutalistTextMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.brutalistBgTertiary)
                                .cornerRadius(6)
                            
                            Text("Updated: \(formatTime(store.lastUpdated))")
                                .font(.system(size: 11))
                                .foregroundColor(Color.brutalistTextMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.brutalistBgTertiary)
                                .cornerRadius(6)
                        }
                        .padding(.top, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(status.status.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.brutalistBgTertiary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isSelected ? Color.brutalistBgSecondary : Color.clear)
            .contentShape(Rectangle())
            
            Divider()
                .background(Color.brutalistBorder)
                .padding(.leading, 52)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    AgentContextView()
}
