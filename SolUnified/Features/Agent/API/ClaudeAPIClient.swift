//
//  ClaudeAPIClient.swift
//  SolUnified
//
//  Handles communication with the Claude API
//

import Foundation

class ClaudeAPIClient: ObservableObject {
    static let shared = ClaudeAPIClient()

    @Published var isProcessing = false
    @Published var lastError: String?

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let defaultModel = "claude-sonnet-4-20250514"

    private var apiKey: String {
        // Get from Settings or Keychain
        return AppSettings.shared.claudeAPIKey
    }

    private init() {}

    // MARK: - Public API

    func complete(
        messages: [ChatMessage],
        systemPrompt: String,
        tools: [AgentTool] = [],
        maxTokens: Int = 4096
    ) async throws -> LLMResponse {
        guard !apiKey.isEmpty else {
            throw ClaudeAPIError.missingAPIKey
        }

        isProcessing = true
        defer { isProcessing = false }

        let request = try buildRequest(
            messages: messages,
            systemPrompt: systemPrompt,
            tools: tools,
            maxTokens: maxTokens
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try parseResponse(data)
    }

    func completeWithContext(
        messages: [ChatMessage],
        context: AssembledContext,
        tools: [AgentTool] = []
    ) async throws -> LLMResponse {
        let systemPrompt = buildSystemPrompt(with: context)
        return try await complete(
            messages: messages,
            systemPrompt: systemPrompt,
            tools: tools
        )
    }

    // MARK: - Request Building

    private func buildRequest(
        messages: [ChatMessage],
        systemPrompt: String,
        tools: [AgentTool],
        maxTokens: Int
    ) throws -> URLRequest {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": defaultModel,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": messages.map { messageToDict($0) }
        ]

        if !tools.isEmpty {
            body["tools"] = tools.map { toolToDict($0) }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func messageToDict(_ message: ChatMessage) -> [String: Any] {
        var dict: [String: Any] = [
            "role": message.role == .assistant ? "assistant" : "user",
            "content": message.content
        ]

        // Handle tool results
        if message.role == .tool, let toolResults = message.toolResults {
            dict["role"] = "user"
            dict["content"] = toolResults.map { result -> [String: Any] in
                return [
                    "type": "tool_result",
                    "tool_use_id": result.toolCallId,
                    "content": result.result
                ]
            }
        }

        return dict
    }

    private func toolToDict(_ tool: AgentTool) -> [String: Any] {
        return [
            "name": tool.rawValue,
            "description": tool.description,
            "input_schema": getToolSchema(tool)
        ]
    }

    private func getToolSchema(_ tool: AgentTool) -> [String: Any] {
        switch tool {
        case .lookupContact:
            return [
                "type": "object",
                "properties": [
                    "name": [
                        "type": "string",
                        "description": "The name to search for"
                    ]
                ],
                "required": ["name"]
            ]

        case .searchMemory:
            return [
                "type": "object",
                "properties": [
                    "keywords": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Keywords to search for in memory"
                    ],
                    "category": [
                        "type": "string",
                        "description": "Optional category filter",
                        "enum": MemoryCategory.allCases.map { $0.rawValue }
                    ]
                ],
                "required": ["keywords"]
            ]

        case .checkCalendar:
            return [
                "type": "object",
                "properties": [
                    "start_date": [
                        "type": "string",
                        "description": "Start date in ISO 8601 format"
                    ],
                    "end_date": [
                        "type": "string",
                        "description": "End date in ISO 8601 format"
                    ]
                ],
                "required": ["start_date", "end_date"]
            ]

        case .createCalendarEvent:
            return [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "description": "Event title"
                    ],
                    "start_time": [
                        "type": "string",
                        "description": "Start time in ISO 8601 format"
                    ],
                    "duration_minutes": [
                        "type": "integer",
                        "description": "Duration in minutes"
                    ],
                    "location": [
                        "type": "string",
                        "description": "Event location"
                    ],
                    "attendees": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "List of attendee emails"
                    ]
                ],
                "required": ["title", "start_time", "duration_minutes"]
            ]

        case .sendEmail:
            return [
                "type": "object",
                "properties": [
                    "to": [
                        "type": "string",
                        "description": "Recipient email address"
                    ],
                    "subject": [
                        "type": "string",
                        "description": "Email subject"
                    ],
                    "body": [
                        "type": "string",
                        "description": "Email body"
                    ]
                ],
                "required": ["to", "subject", "body"]
            ]

        case .searchContext:
            return [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Search query"
                    ]
                ],
                "required": ["query"]
            ]

        case .saveMemory:
            return [
                "type": "object",
                "properties": [
                    "category": [
                        "type": "string",
                        "description": "Memory category",
                        "enum": MemoryCategory.allCases.map { $0.rawValue }
                    ],
                    "key": [
                        "type": "string",
                        "description": "Memory key/identifier"
                    ],
                    "value": [
                        "type": "string",
                        "description": "Memory value/content"
                    ]
                ],
                "required": ["category", "key", "value"]
            ]
        }
    }

    // MARK: - Response Parsing

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.invalidResponse
        }

        guard let content = json["content"] as? [[String: Any]] else {
            throw ClaudeAPIError.invalidResponse
        }

        var textContent = ""
        var toolCalls: [ToolCall] = []

        for block in content {
            if let type = block["type"] as? String {
                if type == "text", let text = block["text"] as? String {
                    textContent = text
                } else if type == "tool_use" {
                    if let id = block["id"] as? String,
                       let name = block["name"] as? String,
                       let input = block["input"] {
                        let inputJson = try? JSONSerialization.data(withJSONObject: input)
                        let inputStr = inputJson.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        toolCalls.append(ToolCall(id: id, toolName: name, arguments: inputStr))
                    }
                }
            }
        }

        let stopReason = json["stop_reason"] as? String

        var usage: LLMUsage?
        if let usageDict = json["usage"] as? [String: Any] {
            usage = LLMUsage(
                promptTokens: usageDict["input_tokens"] as? Int ?? 0,
                completionTokens: usageDict["output_tokens"] as? Int ?? 0,
                totalTokens: (usageDict["input_tokens"] as? Int ?? 0) + (usageDict["output_tokens"] as? Int ?? 0)
            )
        }

        return LLMResponse(
            content: textContent,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            finishReason: stopReason,
            usage: usage
        )
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(with context: AssembledContext) -> String {
        var prompt = """
        You are a helpful AI assistant integrated into Sol Unified, a personal productivity app. You help the user accomplish tasks efficiently by leveraging your knowledge about them and their context.

        Current date and time: \(ISO8601DateFormatter().string(from: context.timestamp))

        """

        // Add work context
        if let workContext = context.workContext {
            prompt += """

            CURRENT WORK CONTEXT:
            \(workContext)

            """
        }

        // Add memories
        if !context.memories.isEmpty {
            prompt += """

            WHAT I KNOW ABOUT THE USER:
            """
            for memory in context.memories {
                prompt += "\n- \(memory.key): \(memory.value)"
            }
            prompt += "\n"
        }

        // Add relevant contacts
        if !context.contacts.isEmpty {
            prompt += """

            RELEVANT CONTACTS:
            """
            for contact in context.contacts {
                var contactInfo = "- \(contact.name)"
                if let email = contact.email { contactInfo += " (\(email))" }
                if let company = contact.company { contactInfo += " - \(company)" }
                prompt += "\n\(contactInfo)"
            }
            prompt += "\n"
        }

        // Add clipboard context if relevant
        if let clipboardContext = context.clipboardContext {
            prompt += """

            RECENT CLIPBOARD:
            \(clipboardContext)

            """
        }

        prompt += """

        GUIDELINES:
        - Be concise and helpful
        - Use the tools available to you when needed
        - Don't ask for information you already have access to
        - When scheduling or creating events, confirm details before executing
        - Learn from interactions and save important facts to memory
        """

        return prompt
    }
}

// MARK: - Errors

enum ClaudeAPIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is not configured. Please add your API key in Settings."
        case .invalidResponse:
            return "Received an invalid response from the Claude API."
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
