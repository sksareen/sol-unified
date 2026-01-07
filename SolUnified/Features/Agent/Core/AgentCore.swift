//
//  AgentCore.swift
//  SolUnified
//
//  The main AI Agent brain - orchestrates context, routing, and tool execution
//

import Foundation
import Combine

class AgentCore: ObservableObject {
    static let shared = AgentCore()

    // Dependencies
    private let claudeAPI = ClaudeAPIClient.shared
    private let contextAssembler = ContextAssembler()
    private let actionDispatcher = ActionDispatcher()
    private let memoryStore = MemoryStore.shared
    private let contactsStore = ContactsStore.shared
    private let conversationStore = ConversationStore.shared

    // State
    @Published var isProcessing = false
    @Published var currentConversation: Conversation?
    @Published var lastError: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Sync conversation state
        conversationStore.$currentConversation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversation in
                self?.currentConversation = conversation
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    func processMessage(_ content: String, in conversation: Conversation? = nil) async throws -> ChatMessage {
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        // 1. Get or create conversation
        let conv = conversation ?? conversationStore.currentConversation ?? conversationStore.createConversation()

        await MainActor.run {
            currentConversation = conv
        }

        // 2. Add user message
        let userMessage = ChatMessage(role: .user, content: content)
        conversationStore.addMessage(userMessage, to: conv)

        // 3. Assemble context
        let context = await contextAssembler.assembleContext(
            for: content,
            conversation: conv,
            memoryStore: memoryStore,
            contactsStore: contactsStore
        )

        // 4. Determine which tools to enable
        let tools = determineTools(for: context)

        // 5. Get conversation history for API
        let messagesForAPI = getMessagesForAPI(conversation: conv)

        do {
            // 6. Call Claude API
            let llmResponse = try await claudeAPI.completeWithContext(
                messages: messagesForAPI,
                context: context,
                tools: tools
            )

            // 7. Handle tool calls if present
            if let toolCalls = llmResponse.toolCalls, !toolCalls.isEmpty {
                return try await handleToolCalls(toolCalls, response: llmResponse, conversation: conv, context: context)
            }

            // 8. Create and save assistant message
            let assistantMessage = ChatMessage(role: .assistant, content: llmResponse.content)
            conversationStore.addMessage(assistantMessage, to: conv)

            // 9. Learn from interaction
            await memoryStore.learnFromInteraction(userMessage: content, response: llmResponse.content)

            // 10. Generate title if needed
            if conv.title == nil && conv.messages.count >= 2 {
                generateTitle(for: conv, firstMessage: content)
            }

            return assistantMessage

        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            throw error
        }
    }

    // MARK: - Tool Handling

    private func handleToolCalls(
        _ toolCalls: [ToolCall],
        response: LLMResponse,
        conversation: Conversation,
        context: AssembledContext
    ) async throws -> ChatMessage {
        // Save assistant message with tool calls
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: response.content,
            toolCalls: toolCalls
        )
        conversationStore.addMessage(assistantMessage, to: conversation)

        // Execute tools
        var toolResults: [ToolResult] = []
        for call in toolCalls {
            let result = await actionDispatcher.dispatch(call)
            toolResults.append(result)
        }

        // Create tool result message
        let toolMessage = ChatMessage(
            role: .tool,
            content: "",
            toolResults: toolResults
        )
        conversationStore.addMessage(toolMessage, to: conversation)

        // Continue conversation with tool results
        return try await continueWithToolResults(conversation: conversation, context: context)
    }

    private func continueWithToolResults(
        conversation: Conversation,
        context: AssembledContext
    ) async throws -> ChatMessage {
        // Get updated messages including tool results
        let messagesForAPI = getMessagesForAPI(conversation: conversation)
        let tools = determineTools(for: context)

        let llmResponse = try await claudeAPI.completeWithContext(
            messages: messagesForAPI,
            context: context,
            tools: tools
        )

        // Check if there are more tool calls
        if let toolCalls = llmResponse.toolCalls, !toolCalls.isEmpty {
            return try await handleToolCalls(toolCalls, response: llmResponse, conversation: conversation, context: context)
        }

        // Final response
        let assistantMessage = ChatMessage(role: .assistant, content: llmResponse.content)
        conversationStore.addMessage(assistantMessage, to: conversation)

        return assistantMessage
    }

    // MARK: - Helper Methods

    private func determineTools(for context: AssembledContext) -> [AgentTool] {
        var tools: [AgentTool] = []

        // Always include basic tools
        tools.append(.lookupContact)
        tools.append(.searchMemory)
        tools.append(.searchContext)
        tools.append(.saveMemory)

        // Add scheduling tools if intent suggests it
        if context.intent.type == .scheduleMeeting {
            tools.append(.checkCalendar)
            tools.append(.createCalendarEvent)
        }

        // Add communication tools
        if context.intent.type == .sendCommunication {
            tools.append(.sendEmail)
        }

        // Check for scheduling keywords
        let schedulingKeywords = ["schedule", "calendar", "meeting", "appointment", "book", "reserve"]
        if schedulingKeywords.contains(where: { context.userQuery.lowercased().contains($0) }) {
            if !tools.contains(.checkCalendar) { tools.append(.checkCalendar) }
            if !tools.contains(.createCalendarEvent) { tools.append(.createCalendarEvent) }
        }

        return tools
    }

    private func getMessagesForAPI(conversation: Conversation) -> [ChatMessage] {
        // Reload conversation to get latest messages
        guard let fullConversation = conversationStore.loadConversation(id: conversation.id) else {
            return []
        }

        // Limit to last N messages to avoid token limits
        let maxMessages = 20
        return Array(fullConversation.messages.suffix(maxMessages))
    }

    private func generateTitle(for conversation: Conversation, firstMessage: String) {
        // Simple title generation - take first few words
        let words = firstMessage.components(separatedBy: .whitespaces)
        let titleWords = words.prefix(5)
        let title = titleWords.joined(separator: " ")
        let truncatedTitle = title.count > 50 ? String(title.prefix(47)) + "..." : title
        conversationStore.updateConversationTitle(conversation.id, title: truncatedTitle)
    }

    // MARK: - Conversation Management

    func startNewConversation() {
        let conversation = conversationStore.startNewConversation()
        currentConversation = conversation
    }

    func setConversation(_ conversation: Conversation) {
        conversationStore.setCurrentConversation(conversation)
    }

    func clearCurrentConversation() {
        currentConversation = nil
        conversationStore.setCurrentConversation(nil)
    }
}
