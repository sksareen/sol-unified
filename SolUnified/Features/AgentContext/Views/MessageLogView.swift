import SwiftUI

struct MessageLogView: View {
    let messages: [AgentMessage]
    @State private var selectedMessage: AgentMessage?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(messages) { message in
                    MessageRow(message: message, isExpanded: selectedMessage?.id == message.id)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedMessage?.id == message.id {
                                    selectedMessage = nil
                                } else {
                                    selectedMessage = message
                                }
                            }
                        }
                }
            }
        }
        .background(Color.brutalistBgSecondary)
    }
}

struct MessageRow: View {
    let message: AgentMessage
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 60, alignment: .leading)
                
                // From → To
                HStack(spacing: 4) {
                    Text(message.from.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(agentColor(message.from))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text((message.to ?? "all").uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(message.to == nil ? .secondary : agentColor(message.to!))
                }
                
                // Priority Badge
                if let priority = message.priority {
                    Text(priority.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor(priority).opacity(0.15))
                        .foregroundColor(priorityColor(priority))
                        .cornerRadius(3)
                }
                
                Spacer()
                
                // Expand indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Content Preview/Full
            if isExpanded {
                // Full content
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                    
                    if let action = message.action_requested {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("ACTION: \(action)")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color.brutalistAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brutalistAccent.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            } else {
                // Preview
                Text(message.content)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .background(Color.brutalistBgPrimary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.brutalistBorder),
            alignment: .bottom
        )
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: timestamp) else {
            return timestamp.prefix(5).description
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }
    
    private func agentColor(_ agent: String) -> Color {
        switch agent.lowercased() {
        case "devon": return Color(hex: "F97316") // Orange
        case "josh": return Color(hex: "10B981") // Green
        case "gunter": return Color(hex: "3B82F6") // Blue
        case "kevin": return Color(hex: "8B5CF6") // Purple
        case "system": return .secondary
        default: return .primary
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "critical": return Color.red
        case "high": return Color.orange
        case "medium": return Color.yellow
        case "low": return Color.secondary
        case "info": return Color.blue
        default: return .secondary
        }
    }
}

#Preview {
    MessageLogView(messages: [
        AgentMessage(
            from: "josh",
            to: "gunter",
            timestamp: "2025-12-19T12:20:00-08:00",
            content: "Strategic pivot update. We're launching ASPIR...",
            priority: "high",
            action_requested: "Assess ASPIR for consciousness research"
        ),
        AgentMessage(
            from: "devon",
            to: "all",
            timestamp: "2025-12-19T16:45:00-08:00",
            content: "I'm Devon, Product Engineer. Looking for UX feedback...",
            priority: "high",
            action_requested: nil
        )
    ])
}
