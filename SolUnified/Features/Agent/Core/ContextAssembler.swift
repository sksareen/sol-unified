//
//  ContextAssembler.swift
//  SolUnified
//
//  Builds context for LLM calls from various sources
//

import Foundation

class ContextAssembler {

    // MARK: - Main Assembly

    func assembleContext(
        for query: String,
        conversation: Conversation,
        memoryStore: MemoryStore,
        contactsStore: ContactsStore
    ) async -> AssembledContext {
        // 1. Extract entities and intent
        let entities = extractEntities(from: query)
        let intent = inferIntent(from: query, entities: entities)

        // 2. Get relevant memories
        let relevantMemories = getRelevantMemories(
            for: query,
            entities: entities,
            memoryStore: memoryStore
        )

        // 3. Get relevant contacts
        let relevantContacts = getRelevantContacts(
            entities: entities,
            contactsStore: contactsStore
        )

        // 4. Get work context
        let workContext = getWorkContext()

        // 5. Get clipboard context if relevant
        let clipboardContext: String? = intent.requiresClipboard ? getClipboardContext() : nil

        // 6. Summarize conversation history
        let conversationHistory = summarizeConversation(conversation)

        return AssembledContext(
            userQuery: query,
            intent: intent,
            memories: relevantMemories,
            contacts: relevantContacts,
            workContext: workContext,
            clipboardContext: clipboardContext,
            conversationHistory: conversationHistory,
            timestamp: Date()
        )
    }

    // MARK: - Entity Extraction

    func extractEntities(from query: String) -> ExtractedEntities {
        var keywords: [String] = []
        var names: [String] = []
        var dates: [String] = []
        var locations: [String] = []

        let words = query.components(separatedBy: .whitespaces)

        // Extract potential names (capitalized words not at start of sentence)
        for (index, word) in words.enumerated() {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)

            // Skip empty words
            guard !cleanWord.isEmpty else { continue }

            // Check for capitalized words (potential names)
            if cleanWord.first?.isUppercase == true && cleanWord.count > 1 {
                // Skip if it's the first word or after punctuation
                let isStartOfSentence = index == 0 || (index > 0 && words[index - 1].last == ".")
                if !isStartOfSentence && !isCommonWord(cleanWord) {
                    names.append(cleanWord)
                }
            }

            // Add as keyword if it's substantial
            if cleanWord.count > 2 && !isStopWord(cleanWord) {
                keywords.append(cleanWord.lowercased())
            }
        }

        // Extract date references
        let dateKeywords = [
            "today", "tomorrow", "yesterday",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "next week", "this week", "next month",
            "morning", "afternoon", "evening"
        ]

        let lowercaseQuery = query.lowercased()
        for keyword in dateKeywords {
            if lowercaseQuery.contains(keyword) {
                dates.append(keyword)
            }
        }

        // Extract location indicators
        let locationPrepositions = ["at", "in", "near", "around"]
        for prep in locationPrepositions {
            if let range = lowercaseQuery.range(of: "\(prep) ") {
                let afterPrep = String(query[range.upperBound...])
                let potentialLocation = afterPrep.components(separatedBy: .whitespaces).first ?? ""
                if !potentialLocation.isEmpty && potentialLocation.first?.isUppercase == true {
                    locations.append(potentialLocation.trimmingCharacters(in: .punctuationCharacters))
                }
            }
        }

        return ExtractedEntities(
            keywords: keywords,
            names: Array(Set(names)),  // Deduplicate
            dates: Array(Set(dates)),
            locations: Array(Set(locations))
        )
    }

    // MARK: - Intent Inference

    func inferIntent(from query: String, entities: ExtractedEntities) -> QueryIntent {
        let lowercaseQuery = query.lowercased()

        // Scheduling intent
        let schedulingKeywords = ["schedule", "book", "reserve", "meeting", "appointment", "calendar", "set up", "arrange"]
        if schedulingKeywords.contains(where: { lowercaseQuery.contains($0) }) {
            return QueryIntent(
                type: .scheduleMeeting,
                entities: entities,
                requiresTools: true,
                requiresClipboard: false
            )
        }

        // Communication intent
        let communicationKeywords = ["email", "send", "message", "write to", "contact", "reach out"]
        if communicationKeywords.contains(where: { lowercaseQuery.contains($0) }) {
            return QueryIntent(
                type: .sendCommunication,
                entities: entities,
                requiresTools: true,
                requiresClipboard: false
            )
        }

        // Search intent
        let searchKeywords = ["find", "search", "look up", "what is", "who is", "where is"]
        if searchKeywords.contains(where: { lowercaseQuery.contains($0) }) {
            return QueryIntent(
                type: .searchInformation,
                entities: entities,
                requiresTools: true,
                requiresClipboard: false
            )
        }

        // Content creation intent
        let createKeywords = ["create", "write", "make", "build", "generate", "draft"]
        if createKeywords.contains(where: { lowercaseQuery.contains($0) }) {
            return QueryIntent(
                type: .createContent,
                entities: entities,
                requiresTools: false,
                requiresClipboard: lowercaseQuery.contains("clipboard") || lowercaseQuery.contains("copied")
            )
        }

        // Task management intent
        let taskKeywords = ["remind", "task", "todo", "add to list", "remember to"]
        if taskKeywords.contains(where: { lowercaseQuery.contains($0) }) {
            return QueryIntent(
                type: .manageTask,
                entities: entities,
                requiresTools: true,
                requiresClipboard: false
            )
        }

        // Default: general intent
        return QueryIntent(
            type: .general,
            entities: entities,
            requiresTools: !entities.names.isEmpty,  // Enable tools if names mentioned
            requiresClipboard: false
        )
    }

    // MARK: - Memory Retrieval

    private func getRelevantMemories(
        for query: String,
        entities: ExtractedEntities,
        memoryStore: MemoryStore
    ) -> [Memory] {
        // Combine keywords and names for search
        var searchTerms = entities.keywords
        searchTerms.append(contentsOf: entities.names.map { $0.lowercased() })

        let memoryQuery = MemoryQuery(
            category: nil,
            keywords: searchTerms,
            minConfidence: 0.5,
            limit: 10
        )

        var memories = memoryStore.query(memoryQuery)

        // If no specific matches, get top memories by usage
        if memories.isEmpty {
            memories = Array(memoryStore.memories
                .sorted { $0.usageCount > $1.usageCount }
                .prefix(5))
        }

        // Record usage for retrieved memories
        for memory in memories {
            memoryStore.recordUsage(memory.id)
        }

        return memories
    }

    // MARK: - Contact Retrieval

    private func getRelevantContacts(
        entities: ExtractedEntities,
        contactsStore: ContactsStore
    ) -> [Contact] {
        var contacts: [Contact] = []

        // Search by extracted names
        for name in entities.names {
            let found = contactsStore.findContact(named: name)
            contacts.append(contentsOf: found)
        }

        // Deduplicate
        var seen = Set<String>()
        contacts = contacts.filter { contact in
            if seen.contains(contact.id) {
                return false
            }
            seen.insert(contact.id)
            return true
        }

        return Array(contacts.prefix(5))  // Limit to 5 contacts
    }

    // MARK: - Work Context

    private func getWorkContext() -> String? {
        // Try to get context from ContextGraph if available
        // For now, return nil - will be integrated with ContextGraphManager
        return nil
    }

    // MARK: - Clipboard Context

    private func getClipboardContext() -> String? {
        // Get recent clipboard items
        let items = ClipboardStore.shared.items.prefix(5)

        if items.isEmpty {
            return nil
        }

        var lines = ["Recent clipboard items:"]
        for item in items {
            if let text = item.contentText {
                let preview = text.prefix(100)
                lines.append("- \(preview)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Conversation Summary

    private func summarizeConversation(_ conversation: Conversation) -> String? {
        guard !conversation.messages.isEmpty else { return nil }

        let recentMessages = conversation.messages.suffix(10)

        var lines = ["Recent conversation:"]
        for message in recentMessages {
            let role = message.role == .user ? "User" : "Assistant"
            let preview = message.content.prefix(100)
            lines.append("\(role): \(preview)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func isCommonWord(_ word: String) -> Bool {
        let common = ["I", "The", "A", "An", "It", "Is", "Are", "Was", "Were", "Be", "Been", "Being"]
        return common.contains(word)
    }

    private func isStopWord(_ word: String) -> Bool {
        let stopWords = [
            "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "must", "can", "to", "of", "in", "for",
            "on", "with", "at", "by", "from", "as", "into", "through", "during",
            "before", "after", "above", "below", "between", "under", "and", "but",
            "or", "nor", "so", "yet", "both", "either", "neither", "not", "only",
            "own", "same", "than", "too", "very", "just", "also", "now", "here",
            "there", "when", "where", "why", "how", "all", "each", "every", "both",
            "few", "more", "most", "other", "some", "such", "no", "any", "this",
            "that", "these", "those", "i", "me", "my", "we", "our", "you", "your",
            "he", "him", "his", "she", "her", "it", "its", "they", "them", "their"
        ]
        return stopWords.contains(word.lowercased())
    }
}
