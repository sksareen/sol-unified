//
//  AgentActionStore.swift
//  SolUnified
//
//  Store for agent-proposed actions awaiting user review
//

import Foundation
import SwiftUI

@MainActor
class AgentActionStore: ObservableObject {
    static let shared = AgentActionStore()

    @Published var actions: [AgentAction] = []
    @Published var pendingCount: Int = 0

    private let storageKey = "agent_actions"
    private let maxActions = 100

    private init() {
        loadActions()
    }

    // MARK: - CRUD

    func addAction(_ action: AgentAction) {
        actions.insert(action, at: 0)

        // Trim old actions
        if actions.count > maxActions {
            actions = Array(actions.prefix(maxActions))
        }

        updatePendingCount()
        saveActions()
    }

    func updateStatus(_ actionId: String, status: AgentActionStatus) {
        if let index = actions.firstIndex(where: { $0.id == actionId }) {
            actions[index].status = status
            actions[index].reviewedAt = Date()
            updatePendingCount()
            saveActions()
        }
    }

    func approve(_ actionId: String) {
        updateStatus(actionId, status: .approved)
    }

    func dismiss(_ actionId: String) {
        updateStatus(actionId, status: .dismissed)
    }

    func complete(_ actionId: String) {
        updateStatus(actionId, status: .completed)
    }

    func removeAction(_ actionId: String) {
        actions.removeAll { $0.id == actionId }
        updatePendingCount()
        saveActions()
    }

    func clearAll() {
        actions.removeAll()
        updatePendingCount()
        saveActions()
    }

    // MARK: - Queries

    var pendingActions: [AgentAction] {
        actions.filter { $0.status == .pending }
    }

    var reviewedActions: [AgentAction] {
        actions.filter { $0.status != .pending }
    }

    func actionsForEvent(_ eventId: String) -> [AgentAction] {
        actions.filter { $0.relatedEventId == eventId }
    }

    // MARK: - Persistence

    private func updatePendingCount() {
        pendingCount = actions.filter { $0.status == .pending }.count
    }

    private func saveActions() {
        do {
            let data = try JSONEncoder().encode(actions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save actions: \(error)")
        }
    }

    private func loadActions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            actions = try JSONDecoder().decode([AgentAction].self, from: data)
            updatePendingCount()
        } catch {
            print("Failed to load actions: \(error)")
        }
    }
}
