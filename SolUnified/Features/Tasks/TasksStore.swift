import Foundation
import Combine

class TasksStore: ObservableObject {
    @Published var tasks: [AgentTask] = []
    @Published var lastUpdated: Date = Date()
    @Published var isSaving: Bool = false
    
    private let statePath = "/Users/savarsareen/coding/mable/agent_state.json"
    private var stateMonitor: DispatchSourceFileSystemObject?
    
    let availableAgents = ["devon", "josh", "gunter", "kevin", "mable"]
    let availableStatuses = ["pending", "in_progress", "completed", "blocked", "archived"]
    let availablePriorities = ["critical", "high", "medium", "low"]
    
    init() {
        loadTasks()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func loadTasks() {
        guard let data = FileManager.default.contents(atPath: statePath) else {
            print("⚠️ Could not read agent_state.json")
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json,
                  let tasksDict = json["tasks"] as? [String: [String: Any]] else {
                print("⚠️ No tasks found in agent_state.json")
                return
            }
            
            var loadedTasks: [AgentTask] = []
            let iso8601Formatter = ISO8601DateFormatter()
            
            for (taskId, taskData) in tasksDict {
                guard let title = taskData["title"] as? String,
                      let description = taskData["description"] as? String,
                      let assignedTo = taskData["assigned_to"] as? String,
                      let status = taskData["status"] as? String,
                      let priority = taskData["priority"] as? String,
                      let createdAtStr = taskData["created_at"] as? String,
                      let updatedAtStr = taskData["updated_at"] as? String,
                      let project = taskData["project"] as? String else {
                    continue
                }
                
                let createdAt = iso8601Formatter.date(from: createdAtStr) ?? Date()
                let updatedAt = iso8601Formatter.date(from: updatedAtStr) ?? Date()
                
                loadedTasks.append(AgentTask(
                    id: taskId,
                    title: title,
                    description: description,
                    assignedTo: assignedTo,
                    status: status,
                    priority: priority,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    project: project
                ))
            }
            
            // Filter out archived tasks and sort by creation date
            tasks = loadedTasks.filter { $0.status != "archived" }.sorted { $0.createdAt > $1.createdAt }
            lastUpdated = Date()
            print("✅ Loaded \(tasks.count) tasks")
        } catch {
            print("Error loading tasks: \(error)")
        }
    }
    
    func addTask(title: String, description: String = "", priority: String = "medium", project: String = "general") {
        let newTask = AgentTask(
            id: UUID().uuidString,
            title: title,
            description: description,
            assignedTo: "mable",
            status: "pending",
            priority: priority,
            createdAt: Date(),
            updatedAt: Date(),
            project: project
        )
        
        tasks.insert(newTask, at: 0)
        saveToFile()
    }
    
    func updateTask(taskId: String, assignedTo: String? = nil, status: String? = nil, description: String? = nil, project: String? = nil) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        var updatedTask = tasks[taskIndex]
        if let assignedTo = assignedTo {
            updatedTask.assignedTo = assignedTo
        }
        if let status = status {
            updatedTask.status = status
        }
        if let description = description {
            updatedTask.description = description
        }
        if let project = project {
            updatedTask.project = project
        }
        updatedTask.updatedAt = Date()
        
        tasks[taskIndex] = updatedTask
        
        saveToFile()
    }
    
    private func saveToFile() {
        isSaving = true
        
        guard let data = FileManager.default.contents(atPath: statePath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("⚠️ Could not read agent_state.json for saving")
            isSaving = false
            return
        }
        
        var tasksDict: [String: [String: Any]] = [:]
        let iso8601Formatter = ISO8601DateFormatter()
        
        for task in tasks {
            tasksDict[task.id] = [
                "id": task.id,
                "title": task.title,
                "description": task.description,
                "assigned_to": task.assignedTo,
                "status": task.status,
                "priority": task.priority,
                "created_at": iso8601Formatter.string(from: task.createdAt),
                "updated_at": iso8601Formatter.string(from: task.updatedAt),
                "project": task.project
            ]
        }
        
        json["tasks"] = tasksDict
        json["last_updated"] = iso8601Formatter.string(from: Date())
        
        do {
            let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try updatedData.write(to: URL(fileURLWithPath: statePath))
            print("✅ Tasks saved to agent_state.json")
        } catch {
            print("Error saving tasks: \(error)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isSaving = false
        }
    }
    
    private func startMonitoring() {
        let fileURL = URL(fileURLWithPath: statePath)
        let fileDescriptor = open(fileURL.path, O_EVTONLY)
        
        guard fileDescriptor != -1 else {
            print("⚠️ Could not open file descriptor for agent_state.json")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.loadTasks()
            }
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        stateMonitor = source
    }
    
    private func stopMonitoring() {
        stateMonitor?.cancel()
        stateMonitor = nil
    }
}
