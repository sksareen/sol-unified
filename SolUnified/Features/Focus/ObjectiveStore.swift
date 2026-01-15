//
//  ObjectiveStore.swift
//  SolUnified
//
//  Manages the current "Objective" - the user's stated intent.
//  This is the compass that guides drift detection and context assembly.
//

import Foundation
import Combine

class ObjectiveStore: ObservableObject {
    static let shared = ObjectiveStore()

    // MARK: - Published State

    @Published var currentObjective: Objective?
    @Published var objectiveHistory: [Objective] = []
    @Published var sessionStartTime: Date?

    // MARK: - Private

    private let db = Database.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCurrentObjective()
    }

    // MARK: - Public API

    /// Set a new objective (triggered by HUD)
    func setObjective(_ text: String) {
        // End previous objective if exists
        if let current = currentObjective {
            endObjective(current, reason: .newObjective)
        }

        let objective = Objective(
            text: text,
            startTime: Date()
        )

        currentObjective = objective
        sessionStartTime = Date()

        // Persist to database
        saveObjective(objective)

        print("🎯 Objective set: \(text)")
    }

    /// Pause the current objective (user acknowledged break)
    func pauseObjective() {
        guard var objective = currentObjective else { return }
        objective.isPaused = true
        objective.pauseStartTime = Date()
        currentObjective = objective
        updateObjective(objective)
        print("⏸ Objective paused: \(objective.text)")
    }

    /// Resume the current objective
    func resumeObjective() {
        guard var objective = currentObjective else { return }
        if let pauseStart = objective.pauseStartTime {
            objective.totalPausedTime += Date().timeIntervalSince(pauseStart)
        }
        objective.isPaused = false
        objective.pauseStartTime = nil
        currentObjective = objective
        updateObjective(objective)
        print("▶️ Objective resumed: \(objective.text)")
    }

    /// Complete the current objective
    func completeObjective() {
        guard let current = currentObjective else { return }
        endObjective(current, reason: .completed)
    }

    /// Abandon the current objective
    func abandonObjective() {
        guard let current = currentObjective else { return }
        endObjective(current, reason: .abandoned)
    }

    /// Get active work duration (excluding paused time)
    var activeWorkDuration: TimeInterval {
        guard let objective = currentObjective,
              let start = sessionStartTime else { return 0 }

        let totalTime = Date().timeIntervalSince(start)
        let pausedTime = objective.totalPausedTime

        // Add current pause time if paused
        if objective.isPaused, let pauseStart = objective.pauseStartTime {
            return totalTime - pausedTime - Date().timeIntervalSince(pauseStart)
        }

        return totalTime - pausedTime
    }

    // MARK: - Private Methods

    private func endObjective(_ objective: Objective, reason: ObjectiveEndReason) {
        var ended = objective
        ended.endTime = Date()
        ended.endReason = reason

        // Calculate final active duration
        if ended.isPaused, let pauseStart = ended.pauseStartTime {
            ended.totalPausedTime += Date().timeIntervalSince(pauseStart)
        }

        // Add to history
        objectiveHistory.insert(ended, at: 0)
        if objectiveHistory.count > 50 {
            objectiveHistory = Array(objectiveHistory.prefix(50))
        }

        // Clear current
        currentObjective = nil
        sessionStartTime = nil

        // Persist
        updateObjective(ended)

        print("✓ Objective ended (\(reason.rawValue)): \(objective.text)")
    }

    private func loadCurrentObjective() {
        // Load active objective from database
        let results = db.query("""
            SELECT * FROM objectives
            WHERE end_time IS NULL
            ORDER BY start_time DESC
            LIMIT 1
        """)

        if let row = results.first,
           let id = row["id"] as? String,
           let text = row["text"] as? String,
           let startTimeStr = row["start_time"] as? String,
           let startTime = Database.stringToDate(startTimeStr) {

            var objective = Objective(id: id, text: text, startTime: startTime)
            objective.isPaused = (row["is_paused"] as? Int ?? 0) == 1
            objective.totalPausedTime = row["total_paused_time"] as? TimeInterval ?? 0

            currentObjective = objective
            sessionStartTime = startTime
        }

        // Load history
        loadHistory()
    }

    private func loadHistory() {
        let results = db.query("""
            SELECT * FROM objectives
            WHERE end_time IS NOT NULL
            ORDER BY end_time DESC
            LIMIT 50
        """)

        objectiveHistory = results.compactMap { row -> Objective? in
            guard let id = row["id"] as? String,
                  let text = row["text"] as? String,
                  let startTimeStr = row["start_time"] as? String,
                  let startTime = Database.stringToDate(startTimeStr) else { return nil }

            var objective = Objective(id: id, text: text, startTime: startTime)

            if let endTimeStr = row["end_time"] as? String {
                objective.endTime = Database.stringToDate(endTimeStr)
            }
            if let reasonStr = row["end_reason"] as? String {
                objective.endReason = ObjectiveEndReason(rawValue: reasonStr)
            }
            objective.totalPausedTime = row["total_paused_time"] as? TimeInterval ?? 0

            return objective
        }
    }

    private func saveObjective(_ objective: Objective) {
        db.execute("""
            INSERT INTO objectives (id, text, start_time, is_paused, total_paused_time)
            VALUES (?, ?, ?, ?, ?)
        """, parameters: [
            objective.id,
            objective.text,
            Database.dateToString(objective.startTime),
            objective.isPaused ? 1 : 0,
            objective.totalPausedTime
        ])
    }

    private func updateObjective(_ objective: Objective) {
        var params: [Any] = [
            objective.isPaused ? 1 : 0,
            objective.totalPausedTime
        ]

        var sql = """
            UPDATE objectives SET
            is_paused = ?,
            total_paused_time = ?
        """

        if let endTime = objective.endTime {
            sql += ", end_time = ?"
            params.append(Database.dateToString(endTime))
        }

        if let endReason = objective.endReason {
            sql += ", end_reason = ?"
            params.append(endReason.rawValue)
        }

        sql += " WHERE id = ?"
        params.append(objective.id)

        db.execute(sql, parameters: params)
    }
}

// MARK: - Models

struct Objective: Identifiable {
    let id: String
    let text: String
    let startTime: Date
    var endTime: Date?
    var endReason: ObjectiveEndReason?
    var isPaused: Bool = false
    var pauseStartTime: Date?
    var totalPausedTime: TimeInterval = 0

    init(id: String = UUID().uuidString, text: String, startTime: Date = Date()) {
        self.id = id
        self.text = text
        self.startTime = startTime
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime) - totalPausedTime
    }

    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

enum ObjectiveEndReason: String {
    case completed
    case abandoned
    case newObjective
}
