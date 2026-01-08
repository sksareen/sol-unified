//
//  ChatView.swift
//  SolUnified
//
//  Main chat interface for the AI Agent
//

import SwiftUI

struct ChatView: View {
    @StateObject private var agent = AgentCore.shared
    @StateObject private var conversationStore = ConversationStore.shared

    @State private var inputText = ""
    @State private var showingConversationList = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Messages
            messagesView

            // Input
            inputView
        }
        .background(Color.brutalistBgPrimary)
        .onAppear {
            inputFocused = true
            if agent.currentConversation == nil {
                agent.startNewConversation()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Agent")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.brutalistTextPrimary)

            Spacer()

            if agent.isProcessing {
                ProgressView()
                    .scaleEffect(0.6)
                    .padding(.trailing, 8)
            }

            // Conversation list button
            Button(action: { showingConversationList.toggle() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
                    .foregroundColor(Color.brutalistTextSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showingConversationList) {
                ConversationListView(
                    conversations: conversationStore.conversations,
                    currentId: agent.currentConversation?.id,
                    onSelect: { conversation in
                        agent.setConversation(conversation)
                        showingConversationList = false
                    },
                    onDelete: { conversation in
                        conversationStore.deleteConversation(id: conversation.id)
                    }
                )
                .frame(width: 300, height: 400)
            }

            // New conversation button
            Button(action: { agent.startNewConversation() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.brutalistAccent)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let conversation = agent.currentConversation {
                        ForEach(conversation.messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .onChange(of: agent.currentConversation?.messages.count) { _ in
                withAnimation {
                    if let lastMessage = agent.currentConversation?.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundColor(Color.brutalistTextSecondary.opacity(0.5))

            Text("Start a conversation")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.brutalistTextSecondary)

            Text("Ask me to schedule meetings, look up contacts, or help with tasks.")
                .font(.system(size: 14))
                .foregroundColor(Color.brutalistTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            // Example prompts
            VStack(spacing: 8) {
                examplePrompt("Schedule coffee with Sarah next week")
                examplePrompt("What do I know about my preferences?")
                examplePrompt("Find contact info for John")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func examplePrompt(_ text: String) -> some View {
        Button(action: {
            inputText = text
            sendMessage()
        }) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color.brutalistAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.brutalistAccent.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Input

    private var inputView: some View {
        VStack(spacing: 0) {
            Divider()

            // Error display
            if let error = agent.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Spacer()
                    Button("Dismiss") {
                        agent.lastError = nil
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color.brutalistTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
            }

            HStack(spacing: 12) {
                TextField("Ask anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color.brutalistBgSecondary)
                    .cornerRadius(8)
                    .focused($inputFocused)
                    .onSubmit {
                        if !inputText.isEmpty && !agent.isProcessing {
                            sendMessage()
                        }
                    }
                    .disabled(agent.isProcessing)

                Button(action: sendMessage) {
                    Image(systemName: agent.isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(
                            inputText.isEmpty && !agent.isProcessing
                                ? Color.brutalistTextSecondary.opacity(0.5)
                                : Color.brutalistAccent
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(inputText.isEmpty && !agent.isProcessing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let message = inputText
        inputText = ""

        Task {
            do {
                _ = try await agent.processMessage(message)
            } catch {
                print("Agent error: \(error)")
            }
        }
    }
}

// MARK: - Conversation List View

struct ConversationListView: View {
    let conversations: [Conversation]
    let currentId: String?
    let onSelect: (Conversation) -> Void
    let onDelete: (Conversation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Conversations")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.brutalistTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            if conversations.isEmpty {
                Text("No conversations yet")
                    .font(.system(size: 13))
                    .foregroundColor(Color.brutalistTextSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(conversations.filter { $0.status != .archived }) { conversation in
                            conversationRow(conversation)
                        }
                    }
                }
            }
        }
        .background(Color.brutalistBgPrimary)
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title ?? "New conversation")
                    .font(.system(size: 14, weight: currentId == conversation.id ? .semibold : .regular))
                    .foregroundColor(Color.brutalistTextPrimary)
                    .lineLimit(1)

                Text(formatDate(conversation.updatedAt))
                    .font(.system(size: 11))
                    .foregroundColor(Color.brutalistTextSecondary)
            }

            Spacer()

            if currentId == conversation.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.brutalistAccent)
                    .font(.system(size: 14))
            }

            Button(action: { onDelete(conversation) }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(Color.brutalistTextSecondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(currentId == conversation.id ? Color.brutalistAccent.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(conversation)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ChatView()
        .frame(width: 600, height: 800)
}
