import SwiftUI
import Combine

// MARK: - Clara Chat View
/// Full-featured ChatGPT-like AI chat interface for personal life insights
struct ClaraChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ClaraChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showingNewChatConfirmation = false

    // Clara gradient colors
    private let claraGradient = LinearGradient(
        colors: [DesignSystem.Colors.violet, DesignSystem.Colors.claraPurpleLight, DesignSystem.Colors.violetDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                claraHeader

                // Chat content
                if viewModel.messages.isEmpty && !viewModel.isTyping {
                    // Empty state with suggestions
                    emptyStateView
                } else {
                    // Chat messages
                    chatMessagesView
                }

                // Input area
                inputArea
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        .alert("Start New Chat?", isPresented: $showingNewChatConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("New Chat", role: .destructive) {
                viewModel.startNewChat()
            }
        } message: {
            Text("This will clear your current conversation with Clara.")
        }
    }

    // MARK: - Header
    private var claraHeader: some View {
        HStack(spacing: 12) {
            // Clara avatar
            ZStack {
                Circle()
                    .fill(claraGradient)
                    .frame(width: 40, height: 40)
                    .shadow(color: DesignSystem.Colors.violet.opacity(0.4), radius: 8, y: 4)

                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Clara")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignSystem.Colors.emerald)
                        .frame(width: 6, height: 6)
                    Text("Your personal AI assistant")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            Spacer()

            // New chat button
            Button(action: {
                if !viewModel.messages.isEmpty {
                    showingNewChatConfirmation = true
                }
            }) {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.violet)
            }
            .opacity(viewModel.messages.isEmpty ? 0.3 : 1.0)
            .disabled(viewModel.messages.isEmpty)

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // Clara intro
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(claraGradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: DesignSystem.Colors.violet.opacity(0.5), radius: 20, y: 10)

                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text("Hi, I'm Clara!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text("I know your calendar, health data, tasks, and habits.\nAsk me anything about your life and I'll give you\nhonest, data-driven insights.")
                        .font(.system(size: 15))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Suggested prompts
                VStack(alignment: .leading, spacing: 16) {
                    Text("Try asking...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        ForEach(viewModel.suggestedPrompts, id: \.self) { prompt in
                            SuggestedPromptButton(prompt: prompt) {
                                viewModel.sendMessage(prompt)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 100)
            }
        }
    }

    // MARK: - Chat Messages
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ClaraMessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isTyping {
                        ClaraTypingBubble()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isTyping) { _, isTyping in
                if isTyping {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DesignSystem.Colors.calmBorder)

            VStack(spacing: 12) {
                // Quick suggestions (context-aware)
                if viewModel.messages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.quickPrompts, id: \.self) { prompt in
                                QuickPromptChip(prompt: prompt) {
                                    viewModel.sendMessage(prompt)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Text input
                HStack(spacing: 12) {
                    // Text field
                    HStack(spacing: 8) {
                        TextField("Ask Clara anything...", text: $viewModel.inputText, axis: .vertical)
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .focused($isInputFocused)
                            .lineLimit(1...5)
                            .submitLabel(.send)
                            .onSubmit {
                                if !viewModel.inputText.isEmpty && !viewModel.isTyping {
                                    viewModel.sendMessage(viewModel.inputText)
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isInputFocused ? DesignSystem.Colors.violet.opacity(0.5) : Color.clear,
                                lineWidth: 1
                            )
                    )

                    // Send button
                    Button(action: {
                        if !viewModel.inputText.isEmpty && !viewModel.isTyping {
                            viewModel.sendMessage(viewModel.inputText)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(claraGradient)
                                .opacity(viewModel.inputText.isEmpty || viewModel.isTyping ? 0.3 : 1.0)
                                .frame(width: 44, height: 44)

                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isTyping)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.inputText.isEmpty)
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.background)
        }
    }
}

// MARK: - Clara Chat ViewModel
@MainActor
class ClaraChatViewModel: ObservableObject {
    @Published var messages: [ClaraMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var sessionId: String? = nil
    @Published var error: String? = nil
    @Published var dynamicPrompts: [ClaraSuggestedPrompt] = []
    @Published var isLoadingPrompts: Bool = false

    // Fallback suggested prompts (used if API fails)
    private let fallbackPrompts: [String] = [
        "How was my sleep this week?",
        "What's my most productive time of day?",
        "Am I over-scheduled this week?",
        "How can I improve my work-life balance?",
        "What patterns do you see in my calendar?",
        "When should I schedule deep work?"
    ]

    // Computed property that returns dynamic prompts or fallback
    var suggestedPrompts: [String] {
        if !dynamicPrompts.isEmpty {
            return dynamicPrompts.map { $0.prompt }
        }
        return fallbackPrompts
    }

    // Quick prompts for bottom bar
    var quickPrompts: [String] {
        if dynamicPrompts.count >= 4 {
            return Array(dynamicPrompts.prefix(4).map { $0.prompt })
        }
        return [
            "Today's overview",
            "Sleep analysis",
            "Meeting load",
            "Energy tips"
        ]
    }

    init() {
        fetchSuggestedPrompts()
    }

    /// Fetch dynamic prompts from the backend
    func fetchSuggestedPrompts() {
        isLoadingPrompts = true
        Task {
            do {
                let prompts = try await ClaraService.shared.getSuggestedPrompts()
                self.dynamicPrompts = prompts
            } catch {
                print("⚠️ Failed to fetch Clara prompts: \(error.localizedDescription)")
                // Keep using fallback prompts
            }
            isLoadingPrompts = false
        }
    }

    func sendMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // Clear input
        inputText = ""

        // Add user message
        let userMessage = ClaraMessage(content: trimmedText, isClara: false)
        messages.append(userMessage)

        // Show typing indicator
        isTyping = true
        error = nil

        // Call API
        Task {
            do {
                let response = try await ClaraService.shared.chat(
                    message: trimmedText,
                    sessionId: sessionId
                )

                isTyping = false
                sessionId = response.sessionId

                let claraMessage = ClaraMessage(content: response.response, isClara: true)
                messages.append(claraMessage)

            } catch {
                isTyping = false
                self.error = error.localizedDescription

                let errorMessage = ClaraMessage(
                    content: "I'm having trouble connecting right now. Please try again in a moment.",
                    isClara: true,
                    isError: true
                )
                messages.append(errorMessage)

                print("❌ Clara chat error: \(error)")
            }
        }
    }

    func startNewChat() {
        messages.removeAll()
        sessionId = nil
        inputText = ""
        error = nil
    }
}

// MARK: - Clara Message Model
struct ClaraMessage: Identifiable {
    let id = UUID()
    let content: String
    let isClara: Bool
    let timestamp: Date = Date()
    var isError: Bool = false
}

// MARK: - Message Bubble
struct ClaraMessageBubble: View {
    let message: ClaraMessage

    private let claraGradient = LinearGradient(
        colors: [DesignSystem.Colors.violet, DesignSystem.Colors.claraPurpleLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let errorGradient = LinearGradient(
        colors: [DesignSystem.Colors.errorRed, DesignSystem.Colors.errorRedDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Renders markdown content for Clara's responses
    private func markdownText(_ content: String, isClara: Bool) -> some View {
        // Use SwiftUI's built-in markdown support
        Text(LocalizedStringKey(content))
            .font(.system(size: 15))
            .foregroundColor(isClara ? DesignSystem.Colors.primaryText : .white)
            .textSelection(.enabled)
            .tint(DesignSystem.Colors.violet) // Link color
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.isClara {
                // Clara avatar
                ZStack {
                    Circle()
                        .fill(message.isError ? errorGradient : claraGradient)
                        .frame(width: 32, height: 32)

                    Image(systemName: message.isError ? "exclamationmark.triangle" : "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Clara message with markdown support
                VStack(alignment: .leading, spacing: 6) {
                    markdownText(message.content, isClara: true)

                    Text(formatTime(message.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .padding(14)
                .background(DesignSystem.Colors.cardBackground)
                .clipShape(ClaraBubbleShape(isFromUser: false))

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                // User message
                VStack(alignment: .trailing, spacing: 6) {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.white)

                    Text(formatTime(message.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(14)
                .background(claraGradient)
                .clipShape(ClaraBubbleShape(isFromUser: true))
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Bubble Shape
struct ClaraBubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailRadius: CGFloat = 6

        var path = Path()

        if isFromUser {
            // User bubble - rounded except bottom right
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                              control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tailRadius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - tailRadius, y: rect.maxY),
                              control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                              control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                              control: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            // Clara bubble - rounded except bottom left
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                              control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                              control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + tailRadius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - tailRadius),
                              control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                              control: CGPoint(x: rect.minX, y: rect.minY))
        }

        return path
    }
}

// MARK: - Typing Indicator
struct ClaraTypingBubble: View {
    @State private var dotAnimation = false

    private let claraGradient = LinearGradient(
        colors: [DesignSystem.Colors.violet, DesignSystem.Colors.claraPurpleLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Clara avatar
            ZStack {
                Circle()
                    .fill(claraGradient)
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Typing dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(DesignSystem.Colors.violet)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotAnimation ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: dotAnimation
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(ClaraBubbleShape(isFromUser: false))

            Spacer()
        }
        .onAppear {
            dotAnimation = true
        }
    }
}

// MARK: - Suggested Prompt Button
struct SuggestedPromptButton: View {
    let prompt: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconForPrompt(prompt))
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.violet)
                    .frame(width: 32)

                Text(prompt)
                    .font(.system(size: 15))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DesignSystem.Colors.violet.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func iconForPrompt(_ prompt: String) -> String {
        let lowercased = prompt.lowercased()
        if lowercased.contains("sleep") { return "moon.stars" }
        if lowercased.contains("productive") || lowercased.contains("focus") { return "target" }
        if lowercased.contains("schedule") || lowercased.contains("calendar") { return "calendar" }
        if lowercased.contains("balance") { return "scale.3d" }
        if lowercased.contains("pattern") { return "chart.line.uptrend.xyaxis" }
        if lowercased.contains("energy") { return "bolt" }
        if lowercased.contains("work") { return "desktopcomputer" }
        return "sparkles"
    }
}

// MARK: - Quick Prompt Chip
struct QuickPromptChip: View {
    let prompt: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(prompt)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DesignSystem.Colors.violet)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.violet.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(DesignSystem.Colors.violet.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    ClaraChatView()
        .preferredColorScheme(.dark)
}
