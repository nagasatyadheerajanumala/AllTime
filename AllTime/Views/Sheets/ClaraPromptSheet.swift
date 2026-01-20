import SwiftUI

/// Sheet for interacting with Clara through pre-defined prompts
/// Supports real-time chat with follow-up questions
struct ClaraPromptSheet: View {
    let prompt: ClaraPrompt
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ClaraChatMessage] = []
    @State private var isTyping = false
    @State private var hasAsked = false
    @State private var followUpText = ""
    @State private var sessionId: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.md) {
                                // Initial greeting from Clara
                                ClaraChatBubble(
                                    message: "Hi! I'm Clara, your AI assistant. How can I help you today?",
                                    isClara: true
                                )
                                .id("greeting")

                                // User's question and Clara's responses
                                ForEach(messages) { message in
                                    ClaraChatBubble(
                                        message: message.content,
                                        isClara: message.isClara
                                    )
                                    .id(message.id)
                                }

                                // Typing indicator
                                if isTyping {
                                    ClaraTypingIndicator()
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.lg)
                        }
                        .onChange(of: messages.count) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: isTyping) { _, newValue in
                            if newValue {
                                withAnimation {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                    }

                    Divider()

                    // Bottom input area
                    inputArea
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ClaraNavigationTitle()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.claraPurple)
                }
            }
        }
    }

    // MARK: - Input Area
    @ViewBuilder
    private var inputArea: some View {
        VStack(spacing: DesignSystem.Spacing.sm + 4) {
            if !hasAsked {
                // Show the prompt as a suggestion button
                ClaraPromptButton(
                    icon: prompt.displayIcon,
                    iconColor: prompt.categoryColor,
                    label: prompt.label ?? "Ask Clara",
                    action: askClara
                )
            } else {
                // Real text field for follow-up questions
                ClaraInputField(
                    text: $followUpText,
                    placeholder: "Type a follow-up...",
                    onSubmit: sendFollowUp,
                    isEnabled: !isTyping
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + 4)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Actions
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if let lastId = messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            } else {
                proxy.scrollTo("greeting", anchor: .bottom)
            }
        }
    }

    private func askClara() {
        hasAsked = true
        errorMessage = nil

        // Add user message
        let userMessageText = prompt.fullPrompt ?? prompt.label ?? "Help me with this"
        messages.append(ClaraChatMessage(content: userMessageText, isClara: false))

        // Show typing indicator
        isTyping = true

        // Call the real Clara API
        Task {
            do {
                let response = try await ClaraService.shared.chat(
                    message: userMessageText,
                    sessionId: sessionId
                )

                await MainActor.run {
                    isTyping = false
                    sessionId = response.sessionId
                    messages.append(ClaraChatMessage(content: response.response, isClara: true))
                }
            } catch {
                await handleChatError(error)
            }
        }
    }

    private func sendFollowUp() {
        guard !followUpText.isEmpty else { return }
        errorMessage = nil

        let userQuestion = followUpText
        followUpText = ""

        // Add user message
        messages.append(ClaraChatMessage(content: userQuestion, isClara: false))

        // Show typing indicator
        isTyping = true

        // Call the real Clara API with conversation continuity
        Task {
            do {
                let response = try await ClaraService.shared.chat(
                    message: userQuestion,
                    sessionId: sessionId
                )

                await MainActor.run {
                    isTyping = false
                    sessionId = response.sessionId
                    messages.append(ClaraChatMessage(content: response.response, isClara: true))
                }
            } catch {
                await handleChatError(error)
            }
        }
    }

    @MainActor
    private func handleChatError(_ error: Error) {
        isTyping = false
        errorMessage = error.localizedDescription

        // Fallback message when API fails
        messages.append(ClaraChatMessage(
            content: "I'm having trouble connecting right now. Please try again in a moment.",
            isClara: true
        ))
        print("❌ Clara chat error: \(error)")
    }
}
