import SwiftUI

struct TasksView: View {
    @StateObject private var store = TasksStore()
    @State private var selectedTask: AgentTask?
    @State private var newTaskTitle = ""
    @State private var isAddingTask = false
    
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
            HStack(spacing: 12) {
                Text("Tasks")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                if store.isSaving {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isAddingTask = true
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.brutalistAccent)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            if isAddingTask {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "circle")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color.brutalistTextMuted)
                        
                        TextField("New Task", text: $newTaskTitle)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .foregroundColor(Color.brutalistTextPrimary)
                            .onSubmit {
                                if !newTaskTitle.isEmpty {
                                    store.addTask(title: newTaskTitle)
                                    newTaskTitle = ""
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isAddingTask = false
                                    }
                                }
                            }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                newTaskTitle = ""
                                isAddingTask = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.brutalistTextMuted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.brutalistBgSecondary)
                    
                    Divider()
                        .background(Color.brutalistBorder)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if store.tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("No Tasks")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedTasks) { task in
                            TaskRow(task: task, store: store, isSelected: selectedTask?.id == task.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedTask = selectedTask?.id == task.id ? nil : task
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
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
    @State private var isHovered = false
    
    var statusColor: Color {
        switch task.status {
        case "completed": return Color(hex: "#34C759")
        case "in_progress": return Color.brutalistAccent
        case "blocked": return Color(hex: "#FF3B30")
        default: return Color.brutalistTextMuted
        }
    }
    
    var categoryColor: Color {
        stringToColor(task.project)
    }
    
    func stringToColor(_ string: String) -> Color {
        let hash = abs(string.hashValue)
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .yellow, .red, .teal, .indigo
        ]
        return colors[hash % colors.count]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: {
                    let newStatus = task.status == "completed" ? "pending" : "completed"
                    store.updateTask(taskId: task.id, status: newStatus)
                }) {
                    ZStack {
                        Circle()
                            .stroke(statusColor, lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                        
                        if task.status == "completed" {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(statusColor)
                        } else if task.status == "in_progress" {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Title", text: Binding(
                        get: { task.title },
                        set: { _ in } // Title editing not requested/implemented fully yet, keeping mostly read-only feel but could add if needed
                    ))
                    .disabled(true) // User didn't explicitly ask for title edit, keeping safe. But description/project yes.
                    // Actually, let's keep title as Text for now to avoid accidental edits if not requested.
                    // Reverting title to Text.
                    
                    Text(task.title)
                        .font(.system(size: 14))
                        .foregroundColor(task.status == "completed" ? Color.brutalistTextMuted : Color.brutalistTextPrimary)
                        .strikethrough(task.status == "completed", color: Color.brutalistTextMuted)
                    
                    if isSelected {
                        // Editable Description
                        TextField("Description", text: Binding(
                            get: { task.description },
                            set: { newVal in store.updateTask(taskId: task.id, description: newVal) }
                        ))
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 12))
                        .foregroundColor(Color.brutalistTextSecondary)
                        .padding(.top, 2)
                        
                        HStack(spacing: 8) {
                            // Editable Project/Category
                            TextField("Project", text: Binding(
                                get: { task.project },
                                set: { newVal in store.updateTask(taskId: task.id, project: newVal) }
                            ))
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 11))
                            .foregroundColor(categoryColor) // Match color
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(categoryColor.opacity(0.1))
                            .cornerRadius(6)
                            .frame(width: 100) // Limit width
                        }
                        .padding(.top, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    StatusPicker(
                        selectedStatus: task.status,
                        availableStatuses: store.availableStatuses,
                        onChange: { newStatus in
                            store.updateTask(taskId: task.id, status: newStatus)
                        }
                    )
                    
                    AgentPicker(
                        selectedAgent: task.assignedTo,
                        availableAgents: store.availableAgents,
                        onChange: { newAgent in
                            store.updateTask(taskId: task.id, assignedTo: newAgent)
                        }
                    )
                }
                
                // Color dot matches category
                Circle()
                    .fill(categoryColor)
                    .frame(width: 6, height: 6)
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
}

struct AgentPicker: View {
    let selectedAgent: String
    let availableAgents: [String]
    let onChange: (String) -> Void
    
    var agentColor: Color {
        switch selectedAgent {
        case "devon": return Color(hex: "#FF3B30")
        case "josh": return Color(hex: "#0A84FF")
        case "gunter": return Color(hex: "#34C759")
        case "kevin": return Color(hex: "#FF9500")
        case "mable": return Color(hex: "#AF52DE")
        default: return Color.brutalistTextMuted
        }
    }
    
    var body: some View {
        Menu {
            ForEach(availableAgents, id: \.self) { agent in
                Button(agent.capitalized) {
                    onChange(agent)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(agentColor)
                    .frame(width: 8, height: 8)
                Text(selectedAgent.capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.brutalistTextSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brutalistBgTertiary)
            .cornerRadius(12)
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
        case "in_progress": return "In Progress"
        case "pending": return "Pending"
        case "completed": return "Completed"
        case "blocked": return "Blocked"
        case "archived": return "Archived"
        default: return selectedStatus.capitalized
        }
    }
    
    var statusIcon: String {
        switch selectedStatus {
        case "in_progress": return "circle.fill"
        case "completed": return "checkmark.circle.fill"
        case "blocked": return "exclamationmark.circle.fill"
        default: return "circle"
        }
    }
    
    var body: some View {
        Menu {
            ForEach(availableStatuses, id: \.self) { status in
                Button(status.replacingOccurrences(of: "_", with: " ").capitalized) {
                    onChange(status)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 10, weight: .medium))
                Text(statusDisplay)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Color.brutalistTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brutalistBgTertiary)
            .cornerRadius(12)
        }
        .menuStyle(BorderlessButtonMenuStyle())
    }
}
