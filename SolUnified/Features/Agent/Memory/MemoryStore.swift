//
//  MemoryStore.swift
//  SolUnified
//
//  Manages long-term memory/facts storage and retrieval
//

import Foundation
import Combine

class MemoryStore: ObservableObject {
    static let shared = MemoryStore()

    @Published var memories: [Memory] = []
    @Published var isLoading = false

    private let db = Database.shared

    private init() {
        loadMemories()
        seedDefaultMemories()
    }

    // MARK: - Load

    func loadMemories() {
        let results = db.query("SELECT * FROM memories ORDER BY usage_count DESC, updated_at DESC")
        DispatchQueue.main.async { [weak self] in
            self?.memories = results.compactMap { self?.memoryFromRow($0) }
        }
    }

    // MARK: - Save

    @discardableResult
    func saveMemory(_ memory: Memory) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO memories
            (id, category, key, value, confidence, source, last_confirmed, usage_count, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        let success = db.execute(sql, parameters: [
            memory.id,
            memory.category.rawValue,
            memory.key,
            memory.value,
            memory.confidence,
            memory.source.rawValue,
            memory.lastConfirmed.map { Database.dateToString($0) } ?? NSNull(),
            memory.usageCount,
            Database.dateToString(memory.createdAt),
            Database.dateToString(memory.updatedAt)
        ])

        if success {
            loadMemories()
        }
        return success
    }

    // MARK: - Delete

    @discardableResult
    func deleteMemory(id: String) -> Bool {
        let success = db.execute("DELETE FROM memories WHERE id = ?", parameters: [id])
        if success {
            loadMemories()
        }
        return success
    }

    // MARK: - Query

    func query(_ query: MemoryQuery) -> [Memory] {
        var filtered = memories

        if let category = query.category {
            filtered = filtered.filter { $0.category == category }
        }

        if !query.keywords.isEmpty {
            filtered = filtered.filter { memory in
                query.keywords.contains { keyword in
                    memory.key.localizedCaseInsensitiveContains(keyword) ||
                    memory.value.localizedCaseInsensitiveContains(keyword)
                }
            }
        }

        filtered = filtered.filter { $0.confidence >= query.minConfidence }

        return Array(filtered.prefix(query.limit))
    }

    func getMemory(category: MemoryCategory, key: String) -> Memory? {
        return memories.first { $0.category == category && $0.key == key }
    }

    func getMemoriesByCategory(_ category: MemoryCategory) -> [Memory] {
        return memories.filter { $0.category == category }
    }

    // MARK: - Usage Tracking

    func recordUsage(_ memoryId: String) {
        guard var memory = memories.first(where: { $0.id == memoryId }) else { return }
        memory.usageCount += 1
        memory.updatedAt = Date()
        _ = saveMemory(memory)
    }

    func confirmMemory(_ memoryId: String) {
        guard var memory = memories.first(where: { $0.id == memoryId }) else { return }
        memory.lastConfirmed = Date()
        memory.confidence = min(1.0, memory.confidence + 0.1)
        memory.updatedAt = Date()
        _ = saveMemory(memory)
    }

    // MARK: - Search

    func searchMemories(query: String, minConfidence: Double = 0.3) -> [Memory] {
        if query.isEmpty {
            return memories.filter { $0.confidence >= minConfidence }
        }

        let results = db.query(
            """
            SELECT * FROM memories
            WHERE (key LIKE ? OR value LIKE ?)
              AND confidence >= ?
            ORDER BY usage_count DESC, updated_at DESC
            LIMIT 50
            """,
            parameters: ["%\(query)%", "%\(query)%", minConfidence]
        )

        return results.compactMap { memoryFromRow($0) }
    }

    // MARK: - Learning

    func learnFact(category: MemoryCategory, key: String, value: String, source: MemorySource = .agentLearned, confidence: Double = 0.7) {
        // Check if memory already exists
        if let existing = getMemory(category: category, key: key) {
            // Update if different value
            if existing.value != value {
                var updated = existing
                updated.value = value
                updated.confidence = confidence
                updated.source = source
                updated.updatedAt = Date()
                _ = saveMemory(updated)
            } else {
                // Same value - just increase confidence
                confirmMemory(existing.id)
            }
        } else {
            // Create new memory
            let memory = Memory(
                category: category,
                key: key,
                value: value,
                confidence: confidence,
                source: source
            )
            _ = saveMemory(memory)
        }
    }

    func learnFromInteraction(userMessage: String, response: String) async {
        // Pattern detection for automatic memory creation
        // This is a simple implementation - could be enhanced with NLP

        let lowercaseMessage = userMessage.lowercased()

        // Detect preferences
        if lowercaseMessage.contains("i prefer") || lowercaseMessage.contains("i like") {
            // Extract what they prefer (simple heuristic)
            if let range = lowercaseMessage.range(of: "i prefer ") ?? lowercaseMessage.range(of: "i like ") {
                let preference = String(userMessage[range.upperBound...])
                    .trimmingCharacters(in: .punctuationCharacters)
                    .trimmingCharacters(in: .whitespaces)
                if !preference.isEmpty && preference.count < 100 {
                    learnFact(
                        category: .userPreference,
                        key: "user_stated_preference_\(Date().timeIntervalSince1970)",
                        value: preference,
                        source: .userStated,
                        confidence: 0.9
                    )
                }
            }
        }

        // Detect routines
        if lowercaseMessage.contains("i usually") || lowercaseMessage.contains("i always") {
            if let range = lowercaseMessage.range(of: "i usually ") ?? lowercaseMessage.range(of: "i always ") {
                let routine = String(userMessage[range.upperBound...])
                    .trimmingCharacters(in: .punctuationCharacters)
                    .trimmingCharacters(in: .whitespaces)
                if !routine.isEmpty && routine.count < 100 {
                    learnFact(
                        category: .routine,
                        key: "user_stated_routine_\(Date().timeIntervalSince1970)",
                        value: routine,
                        source: .userStated,
                        confidence: 0.85
                    )
                }
            }
        }

        // Detect work context
        if lowercaseMessage.contains("i work") || lowercaseMessage.contains("my job") {
            if let range = lowercaseMessage.range(of: "i work ") ?? lowercaseMessage.range(of: "my job ") {
                let workInfo = String(userMessage[range.upperBound...])
                    .trimmingCharacters(in: .punctuationCharacters)
                    .trimmingCharacters(in: .whitespaces)
                if !workInfo.isEmpty && workInfo.count < 100 {
                    learnFact(
                        category: .workContext,
                        key: "work_info_\(Date().timeIntervalSince1970)",
                        value: workInfo,
                        source: .userStated,
                        confidence: 0.9
                    )
                }
            }
        }
    }

    // MARK: - Seeding

    private func seedDefaultMemories() {
        // Only seed if empty
        guard memories.isEmpty else { return }

        let defaults: [(MemoryCategory, String, String)] = [
            (.userPreference, "timezone", TimeZone.current.identifier),
            (.userPreference, "locale", Locale.current.identifier),
            (.userPreference, "language", Locale.current.language.languageCode?.identifier ?? "en")
        ]

        for (category, key, value) in defaults {
            let memory = Memory(
                category: category,
                key: key,
                value: value,
                confidence: 0.9,
                source: .inferred
            )
            _ = saveMemory(memory)
        }

        loadMemories()
    }

    // MARK: - Export for Agent Context

    func getContextSummary(limit: Int = 10) -> String {
        let topMemories = memories
            .sorted { $0.usageCount > $1.usageCount }
            .prefix(limit)

        if topMemories.isEmpty {
            return "No memories stored yet."
        }

        var lines: [String] = ["Key facts about the user:"]
        for memory in topMemories {
            lines.append("- \(memory.key): \(memory.value)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Row Parsing

    private func memoryFromRow(_ row: [String: Any]) -> Memory? {
        guard let id = row["id"] as? String,
              let categoryStr = row["category"] as? String,
              let category = MemoryCategory(rawValue: categoryStr),
              let key = row["key"] as? String,
              let value = row["value"] as? String else {
            return nil
        }

        let source = MemorySource(rawValue: row["source"] as? String ?? "inferred") ?? .inferred

        return Memory(
            id: id,
            category: category,
            key: key,
            value: value,
            confidence: row["confidence"] as? Double ?? 1.0,
            source: source,
            lastConfirmed: Database.stringToDate(row["last_confirmed"] as? String ?? ""),
            usageCount: row["usage_count"] as? Int ?? 0,
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            updatedAt: Database.stringToDate(row["updated_at"] as? String ?? "") ?? Date()
        )
    }
}
