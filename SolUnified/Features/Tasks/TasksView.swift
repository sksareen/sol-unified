import SwiftUI

struct TasksView: View {
    @StateObject private var store = TasksStore()
    @State private var selectedTask: AgentTask?
    
    var sortedTasks: [AgentTask] {
        store.tasks.sorted { task1, task2 in
            let priority1 = statusPriority(task1.status)
            let priority2 = statusPriority(task2.status)
            return priority1 < priority2
        }
    }
    
    func statusPriority(_ status: String) -> Int {
        switch status {
        case "in_progress": return 0
        case "blocked": return 1
        case "pending": return 2
        case "completed": return 3
        default: return 4
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TASKS")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                Text("\(store.tasks.count) tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.brutalistTextSecondary)
                
                if store.isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.leading, 8)
                }
            }
            .padding(16)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            if store.tasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(Color.brutalistTextSecondary)
                    
                    Text("No tasks")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(sortedTasks) { task in
                            TaskRow(task: task, store: store, isSelected: selectedTask?.id == task.id)
                                .onTapGesture {
                                    selectedTask = task
                                }
                        }
                    }
                }
            }
        }
        .background(Color.brutalistBgPrimary)
    }
}

struct TaskRow: View {
    let task: AgentTask
    @ObservedObject var store: TasksStore
    let isSelected: Bool
    @State private var isExpanded: Bool = false
    
    var priorityColor: Color {
        switch task.priority {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .gray
        default: return .gray
        }
    }
    
    var statusColor: Color {
        switch task.status {
        case "completed": return .green
        case "in_progress": return .blue
        case "blocked": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(task.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.brutalistTextPrimary)
                        
                        Spacer()
                        
                        Rectangle()
                            .fill(priorityColor)
                            .frame(width: 3, height: 14)
                    }
                    
                    HStack(spacing: 8) {
                        AgentPicker(
                            selectedAgent: task.assignedTo,
                            availableAgents: store.availableAgents,
                            onChange: { newAgent in
                                store.updateTask(taskId: task.id, assignedTo: newAgent, status: nil)
                            }
                        )
                        
                        StatusPicker(
                            selectedStatus: task.status,
                            availableStatuses: store.availableStatuses,
                            onChange: { newStatus in
                                store.updateTask(taskId: task.id, assignedTo: nil, status: newStatus)
                            }
                        )
                        
                        Spacer()
                        
                        Text(task.project.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(Color.brutalistTextSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.brutalistBgTertiary)
                    }
                    
                    if isExpanded {
                        Text(task.description)
                            .font(.system(size: 11))
                            .foregroundColor(Color.brutalistTextSecondary)
                            .padding(.top, 4)
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                            Text(isExpanded ? "Less" : "More")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.5)
                        }
                        .foregroundColor(Color.brutalistTextSecondary)
                        .padding(.top, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .background(isSelected ? Color.brutalistBgTertiary : Color.brutalistBgSecondary)
            
            Rectangle()
                .fill(Color.brutalistBorder)
                .frame(height: 1)
        }
    }
}

struct AgentPicker: View {
    let selectedAgent: String
    let availableAgents: [String]
    let onChange: (String) -> Void
    
    var body: some View {
        Menu {
            ForEach(availableAgents, id: \.self) { agent in
                Button(agent.uppercased()) {
                    onChange(agent)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 10))
                Text(selectedAgent.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(Color.brutalistTextPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brutalistBgTertiary)
            .cornerRadius(4)
        }
        .menuStyle(BorderlessButtonMenuStyle())
    }
}

struct StatusPicker: View {
    let selectedStatus: String
    let availableStatuses: [String]
    let onChange: (String) -> Void
    
    var statusDisplay: String {
        switch selectedStatus {
        case "in_progress": return "IN PROGRESS"
        default: return selectedStatus.uppercased()
        }
    }
    
    var body: some View {
        Menu {
            ForEach(availableStatuses, id: \.self) { status in
                Button(status.uppercased().replacingOccurrences(of: "_", with: " ")) {
                    onChange(status)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(statusDisplay)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(Color.brutalistTextPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brutalistBgPrimary)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.brutalistBorder, lineWidth: 1)
            )
        }
        .menuStyle(BorderlessButtonMenuStyle())
    }
}
