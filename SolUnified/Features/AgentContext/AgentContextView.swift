import SwiftUI

struct AgentContextView: View {
    @StateObject private var store = AgentContextStore()
    @State private var viewMode: ViewMode = .status
    
    enum ViewMode: String, CaseIterable {
        case status = "Status"
        case console = "Console"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Toggle
            HStack {
                Text("AGENTS")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            // Content
            if viewMode == .status {
                HStack(spacing: 0) {
                    // Josh (Product) Column
                    AgentColumn(
                        name: "Josh",
                        role: "Product & Earn",
                        color: Color(hex: "F97316"), // Orange
                        context: store.joshContext
                    )
                    
                    // Divider
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 1)
                    
                    // Gunter (Research) Column
                    AgentColumn(
                        name: "Gunter",
                        role: "Research & Science",
                        color: Color(hex: "3B82F6"), // Blue
                        context: store.researchContext
                    )
                }
                .background(Color(nsColor: .windowBackgroundColor))
            } else {
                AgentConsoleView()
            }
        }
    }
}

struct AgentColumn: View {
    let name: String
    let role: String
    let color: Color
    let context: AgentContext?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.system(size: 14, weight: .bold))
                    Text(role)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(color.opacity(0.1))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(nsColor: .separatorColor)),
                alignment: .bottom
            )
            
            if let context = context {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Status Section
                        VStack(alignment: .leading, spacing: 8) {
                            Label("CURRENT STATUS", systemImage: "activity")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text(context.status)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(10)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                        }
                        
                        // Mission Section
                        VStack(alignment: .leading, spacing: 8) {
                            Label("MISSION", systemImage: "target")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text(context.mission)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Todos Section
                        VStack(alignment: .leading, spacing: 8) {
                            Label("ACTIVE TASKS", systemImage: "list.bullet")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ForEach(context.todos, id: \.self) { todo in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 10))
                                        .padding(.top, 4)
                                        .foregroundColor(color)
                                    
                                    Text(todo)
                                        .font(.system(size: 13))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Text("No Context Found")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Waiting for agent to initialize...")
                        .font(.system(size: 10))
                        .foregroundColor(Color.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
