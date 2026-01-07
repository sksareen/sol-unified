//
//  ConversationStore.swift
//  SolUnified
//
//  Manages conversation and chat message persistence
//

import Foundation
import Combine

class ConversationStore: ObservableObject {
    static let shared = ConversationStore()

    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isLoading = false

    private let db = Database.shared

    private init() {
        loadConversations()
    }

    // MARK: - Load

    func loadConversations() {
        let results = db.query(
            "SELECT * FROM conversations ORDER BY updated_at DESC LIMIT 50"
        )
        DispatchQueue.main.async { [weak self] in
            self?.conversations = results.compactMap { self?.conversationFromRow($0) }
        }
    }

    func loadConversation(id: String) -> Conversation? {
        let results = db.query("SELECT * FROM conversations WHERE id = ?", parameters: [id])
        guard let row = results.first,
              var conversation = conversationFromRow(row) else {
            return nil
        }

        // Load messages
        conversation.messages = loadMessages(forConversationId: id)
        return conversation
    }

    func loadMessages(forConversationId conversationId: String) -> [ChatMessage] {
        let results = db.query(
            "SELECT * FROM chat_messages WHERE conversation_id = ? ORDER BY timestamp ASC",
            parameters: [conversationId]
        )
        return results.compactMap { messageFromRow($0) }
    }

    // MARK: - Create

    func createConversation(title: String? = nil) -> Conversation {
        let conversation = Conversation(
            title: title,
            messages: [],
            status: .active
        )

        _ = saveConversation(conversation)
        DispatchQueue.main.async { [weak self] in
            self?.currentConversation = conversation
        }
        return conversation
    }

    // MARK: - Save

    @discardableResult
    func saveConversation(_ conversation: Conversation) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO conversations
            (id, title, status, context_snapshot, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """

        let success = db.execute(sql, parameters: [
            conversation.id,
            conversation.title ?? NSNull(),
            conversation.status.rawValue,
            conversation.contextSnapshot ?? NSNull(),
            Database.dateToString(conversation.createdAt),
            Database.dateToString(conversation.updatedAt)
        ])

        if success {
            loadConversations()
        }
        return success
    }

    @discardableResult
    func saveMessage(_ message: ChatMessage, toConversationId conversationId: String) -> Bool {
        let toolCallsJson = message.toolCalls.flatMap { try? JSONEncoder().encode($0) }
        let toolCallsStr = toolCallsJson.flatMap { String(data: $0, encoding: .utf8) }

        let toolResultsJson = message.toolResults.flatMap { try? JSONEncoder().encode($0) }
        let toolResultsStr = toolResultsJson.flatMap { String(data: $0, encoding: .utf8) }

        let sql = """
            INSERT INTO chat_messages
            (id, conversation_id, role, content, tool_calls, tool_results, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        let success = db.execute(sql, parameters: [
            message.id,
            conversationId,
            message.role.rawValue,
            message.content,
            toolCallsStr ?? NSNull(),
            toolResultsStr ?? NSNull(),
            Database.dateToString(message.timestamp)
        ])

        if success {
            // Update conversation's updated_at
            _ = db.execute(
                "UPDATE conversations SET updated_at = ? WHERE id = ?",
                parameters: [Database.dateToString(Date()), conversationId]
            )

            // Update current conversation if it matches
            if currentConversation?.id == conversationId {
                DispatchQueue.main.async { [weak self] in
                    self?.currentConversation?.messages.append(message)
                    self?.currentConversation?.updatedAt = Date()
                }
            }
        }

        return success
    }

    // MARK: - Add Message

    func addMessage(_ message: ChatMessage, to conversation: Conversation) {
        _ = saveMessage(message, toConversationId: conversation.id)
    }

    func addUserMessage(_ content: String, to conversation: Conversation) -> ChatMessage {
        let message = ChatMessage(role: .user, content: content)
        addMessage(message, to: conversation)
        return message
    }

    func addAssistantMessage(_ content: String, toolCalls: [ToolCall]? = nil, to conversation: Conversation) -> ChatMessage {
        let message = ChatMessage(role: .assistant, content: content, toolCalls: toolCalls)
        addMessage(message, to: conversation)
        return message
    }

    // MARK: - Update

    func updateConversationStatus(_ conversationId: String, status: ConversationStatus) {
        _ = db.execute(
            "UPDATE conversations SET status = ?, updated_at = ? WHERE id = ?",
            parameters: [status.rawValue, Database.dateToString(Date()), conversationId]
        )

        if currentConversation?.id == conversationId {
            DispatchQueue.main.async { [weak self] in
                self?.currentConversation?.status = status
            }
        }

        loadConversations()
    }

    func updateConversationTitle(_ conversationId: String, title: String) {
        _ = db.execute(
            "UPDATE conversations SET title = ?, updated_at = ? WHERE id = ?",
            parameters: [title, Database.dateToString(Date()), conversationId]
        )

        if currentConversation?.id == conversationId {
            DispatchQueue.main.async { [weak self] in
                self?.currentConversation?.title = title
            }
        }

        loadConversations()
    }

    // MARK: - Delete

    @discardableResult
    func deleteConversation(id: String) -> Bool {
        // Delete messages first
        _ = db.execute("DELETE FROM chat_messages WHERE conversation_id = ?", parameters: [id])
        // Then delete conversation
        let success = db.execute("DELETE FROM conversations WHERE id = ?", parameters: [id])

        if success {
            if currentConversation?.id == id {
                DispatchQueue.main.async { [weak self] in
                    self?.currentConversation = nil
                }
            }
            loadConversations()
        }
        return success
    }

    func archiveConversation(id: String) {
        updateConversationStatus(id, status: .archived)
    }

    // MARK: - Current Conversation

    func setCurrentConversation(_ conversation: Conversation?) {
        DispatchQueue.main.async { [weak self] in
            if let conv = conversation {
                // Load full conversation with messages
                self?.currentConversation = self?.loadConversation(id: conv.id)
            } else {
                self?.currentConversation = nil
            }
        }
    }

    func startNewConversation() -> Conversation {
        return createConversation()
    }

    // MARK: - Search

    func searchConversations(query: String) -> [Conversation] {
        if query.isEmpty {
            return conversations.filter { $0.status != .archived }
        }

        let results = db.query(
            """
            SELECT DISTINCT c.* FROM conversations c
            LEFT JOIN chat_messages m ON c.id = m.conversation_id
            WHERE c.title LIKE ?
               OR m.content LIKE ?
            ORDER BY c.updated_at DESC
            LIMIT 20
            """,
            parameters: ["%\(query)%", "%\(query)%"]
        )

        return results.compactMap { conversationFromRow($0) }
    }

    // MARK: - Statistics

    func getConversationStats() -> (total: Int, active: Int, messagesTotal: Int) {
        let total = conversations.count
        let active = conversations.filter { $0.status == .active }.count

        let messageCountResult = db.query("SELECT COUNT(*) as count FROM chat_messages")
        let messagesTotal = messageCountResult.first?["count"] as? Int ?? 0

        return (total, active, messagesTotal)
    }

    // MARK: - Row Parsing

    private func conversationFromRow(_ row: [String: Any]) -> Conversation? {
        guard let id = row["id"] as? String else { return nil }

        let status = ConversationStatus(rawValue: row["status"] as? String ?? "active") ?? .active

        return Conversation(
            id: id,
            title: row["title"] as? String,
            messages: [],  // Messages loaded separately
            status: status,
            contextSnapshot: row["context_snapshot"] as? String,
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            updatedAt: Database.stringToDate(row["updated_at"] as? String ?? "") ?? Date()
        )
    }

    private func messageFromRow(_ row: [String: Any]) -> ChatMessage? {
        guard let id = row["id"] as? String,
              let roleStr = row["role"] as? String,
              let role = MessageRole(rawValue: roleStr),
              let content = row["content"] as? String else {
            return nil
        }

        var toolCalls: [ToolCall]?
        if let toolCallsStr = row["tool_calls"] as? String,
           let toolCallsData = toolCallsStr.data(using: .utf8) {
            toolCalls = try? JSONDecoder().decode([ToolCall].self, from: toolCallsData)
        }

        var toolResults: [ToolResult]?
        if let toolResultsStr = row["tool_results"] as? String,
           let toolResultsData = toolResultsStr.data(using: .utf8) {
            toolResults = try? JSONDecoder().decode([ToolResult].self, from: toolResultsData)
        }

        return ChatMessage(
            id: id,
            role: role,
            content: content,
            toolCalls: toolCalls,
            toolResults: toolResults,
            timestamp: Database.stringToDate(row["timestamp"] as? String ?? "") ?? Date()
        )
    }
}
