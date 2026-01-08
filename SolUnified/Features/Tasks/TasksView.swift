import SwiftUI
import UniformTypeIdentifiers

struct TasksView: View {
    @StateObject private var store = TasksStore()
    @State private var selectedTask: AgentTask?
    @State private var newTaskTitle = ""
    @State private var isAddingTask = false
    @State private var draggedTaskId: String?
    
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
                
                // Archive completed tasks button
                if store.completedTasksCount > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            store.archiveCompletedTasks()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 12, weight: .medium))
                            Text("Archive \(store.completedTasksCount)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color.brutalistTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.brutalistBgTertiary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Archive all completed tasks")
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
                                .onDrag {
                                    draggedTaskId = task.id
                                    return NSItemProvider(object: task.id as NSString)
                                }
                                .onDrop(of: [.text], delegate: TaskDropDelegate(
                                    task: task,
                                    tasks: $store.tasks,
                                    store: store,
                                    draggedTaskId: $draggedTaskId
                                ))
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
    @State private var isDragHovered = false
    
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
            HStack(alignment: .center, spacing: 8) {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHovered ? Color.brutalistTextSecondary : Color.brutalistTextMuted.opacity(0.4))
                    .frame(width: 16)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.openHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                
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
                    .frame(width: 30, height: 30) // Larger hit area
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Title", text: Binding(
                        get: { task.title },
                        set: { newVal in store.updateTask(taskId: task.id, title: newVal) }
                    ))
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .foregroundColor(task.status == "completed" ? Color.brutalistTextMuted : Color.brutalistTextPrimary)
                    // Add strikethrough effect simulation if needed, but TextField doesn't support it natively easily.
                    // For now, text color change is enough.
                    
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
                    // Assignee picker (Me vs Agent)
                    AssigneePicker(
                        selectedAssignee: task.assignedTo,
                        onChange: { newAssignee in
                            store.updateTask(taskId: task.id, assignedTo: newAssignee)
                        }
                    )
                    .frame(width: 70)
                    
                    StatusPicker(
                        selectedStatus: task.status,
                        availableStatuses: store.availableStatuses,
                        onChange: { newStatus in
                            store.updateTask(taskId: task.id, status: newStatus)
                        }
                    )
                    .frame(width: 90) // Fixed width for alignment
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
                .padding(.leading, 68)
        }
        .background(isDragHovered ? Color.brutalistAccent.opacity(0.1) : Color.clear)
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
                    .font(.system(size: 9, weight: .bold)) // Slightly smaller, bolder icon
                Text(statusDisplay)
                    .font(.system(size: 10, weight: .medium)) // Smaller font
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(Color.brutalistTextMuted.opacity(0.7))
            }
            .foregroundColor(Color.brutalistTextSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brutalistBgTertiary)
            .cornerRadius(6) // Sharper corners for brutalist look
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.brutalistBorder.opacity(0.5), lineWidth: 1)
            )
        }
        .menuStyle(BorderlessButtonMenuStyle())
    }
}

// MARK: - Assignee Picker (Me vs Agent)
struct AssigneePicker: View {
    let selectedAssignee: String
    let onChange: (String) -> Void
    
    var isMe: Bool {
        selectedAssignee == "me" || selectedAssignee == "self"
    }
    
    var displayName: String {
        isMe ? "Me" : "Agent"
    }
    
    var icon: String {
        isMe ? "person.fill" : "cpu"
    }
    
    var color: Color {
        isMe ? Color.brutalistAccent : Color(hex: "#AF52DE")
    }
    
    var body: some View {
        Menu {
            Button {
                onChange("me")
            } label: {
                Label("Me", systemImage: "person.fill")
            }
            Button {
                onChange("agent")
            } label: {
                Label("Agent", systemImage: "cpu")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                Text(displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(6)
        }
        .menuStyle(BorderlessButtonMenuStyle())
    }
}

// MARK: - Task Drag and Drop
struct TaskDropDelegate: DropDelegate {
    let task: AgentTask
    @Binding var tasks: [AgentTask]
    let store: TasksStore
    @Binding var draggedTaskId: String?
    
    func performDrop(info: DropInfo) -> Bool {
        // Save the reordered tasks
        store.reorderTasks(tasks)
        draggedTaskId = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTaskId,
              let fromIndex = tasks.firstIndex(where: { $0.id == draggedId }),
              let toIndex = tasks.firstIndex(where: { $0.id == task.id }),
              fromIndex != toIndex else {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            let movedTask = tasks.remove(at: fromIndex)
            tasks.insert(movedTask, at: toIndex)
        }
    }
    
    func dropExited(info: DropInfo) {
        // No-op
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return draggedTaskId != nil
    }
}
