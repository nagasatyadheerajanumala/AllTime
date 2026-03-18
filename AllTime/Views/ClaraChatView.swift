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

    // MARK: - Time-aware greeting
    private var timeAwareGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Hey there"
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 32)

                // Clara intro with animated avatar
                VStack(spacing: 20) {
                    // Animated glowing avatar
                    ClaraAnimatedAvatar()

                    VStack(spacing: 8) {
                        Text("\(timeAwareGreeting), I'm Clara")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text("Your personal AI assistant")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.violet)
                    }
                }

                // Capability pills
                capabilityPills
                    .padding(.horizontal, 20)

                // Suggested prompts with categories
                VStack(alignment: .leading, spacing: 14) {
                    Text("Try asking...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        ForEach(viewModel.suggestedPrompts, id: \.self) { prompt in
                            EnhancedSuggestedPromptButton(prompt: prompt) {
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

    // MARK: - Capability Pills
    private var capabilityPills: some View {
        let capabilities: [(icon: String, text: String, color: Color)] = [
            ("calendar", "Calendar", DesignSystem.Colors.blue),
            ("heart.fill", "Health", DesignSystem.Colors.errorRed),
            ("checkmark.circle", "Tasks", DesignSystem.Colors.emerald),
            ("chart.bar.fill", "Insights", DesignSystem.Colors.amber)
        ]

        return HStack(spacing: 8) {
            ForEach(capabilities, id: \.text) { cap in
                HStack(spacing: 6) {
                    Image(systemName: cap.icon)
                        .font(.system(size: 12))
                        .foregroundColor(cap.color)
                    Text(cap.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(cap.color.opacity(0.1))
                .clipShape(Capsule())
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

                    if viewModel.isTyping && !viewModel.messages.contains(where: { $0.isStreaming }) {
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

        Task {
            // Use non-streaming for reliability — streaming can be re-enabled
            // once the backend SSE endpoint is confirmed working in production
            await sendWithoutStreaming(trimmedText)
        }
    }

    /// Send message via SSE streaming, fall back to non-streaming on failure
    private func sendWithStreaming(_ text: String) async {
        // Add a placeholder Clara message for streaming
        var claraMessage = ClaraMessage(content: "", isClara: true, isStreaming: true)
        let claraMessageId = claraMessage.id
        messages.append(claraMessage)
        isTyping = false // We have the streaming bubble now

        var collectedToolResults: [ToolResultForUI] = []
        var streamFailed = false

        do {
            let stream = ClaraService.shared.chatStream(message: text, sessionId: sessionId)

            for try await event in stream {
                guard let idx = messages.firstIndex(where: { $0.id == claraMessageId }) else { continue }

                switch event {
                case .status(let msg):
                    messages[idx].statusMessage = msg

                case .toolResult(let result):
                    collectedToolResults.append(result)
                    messages[idx].toolResults = collectedToolResults
                    // Post refresh notifications for mutations
                    postRefreshNotification(for: result.toolName)

                case .token(let tokenText):
                    messages[idx].statusMessage = nil
                    messages[idx].content += tokenText

                case .done(let doneData):
                    messages[idx].content = doneData.response
                    messages[idx].isStreaming = false
                    messages[idx].statusMessage = nil
                    messages[idx].insights = doneData.insights
                    messages[idx].contextMetrics = doneData.contextMetrics
                    if let results = doneData.toolResults, !results.isEmpty {
                        messages[idx].toolResults = results
                    }
                    sessionId = doneData.sessionId

                    // Post refresh for any mutation tool results
                    if let results = doneData.toolResults {
                        for result in results {
                            postRefreshNotification(for: result.toolName)
                        }
                    }

                case .error(let msg):
                    messages[idx].content = msg
                    messages[idx].isStreaming = false
                    messages[idx].isError = true
                }
            }

            // Mark streaming complete
            if let idx = messages.firstIndex(where: { $0.id == claraMessageId }) {
                messages[idx].isStreaming = false
                // Safety net: if stream completed but no content received, fall back
                if messages[idx].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && messages[idx].toolResults == nil
                    && !messages[idx].isError {
                    print("⚠️ Stream completed with empty content, falling back to non-streaming")
                    streamFailed = true
                    messages.removeAll { $0.id == claraMessageId }
                }
            }

        } catch {
            streamFailed = true
            print("⚠️ Stream failed, falling back to non-streaming: \(error)")

            // Remove the streaming placeholder
            messages.removeAll { $0.id == claraMessageId }
        }

        // Fallback to non-streaming if stream failed or empty
        if streamFailed {
            await sendWithoutStreaming(text)
        }
    }

    /// Non-streaming fallback using the regular chat endpoint
    private func sendWithoutStreaming(_ text: String) async {
        isTyping = true

        do {
            let response = try await ClaraService.shared.chat(
                message: text,
                sessionId: sessionId
            )

            isTyping = false
            sessionId = response.sessionId

            var claraMessage = ClaraMessage(content: response.response, isClara: true)
            claraMessage.insights = response.insights
            claraMessage.contextMetrics = response.contextMetrics
            claraMessage.actionResult = response.actionResult
            claraMessage.toolResults = response.toolResults
            messages.append(claraMessage)

            // Post notifications for legacy action results
            if let actionResult = response.actionResult, actionResult.success {
                postRefreshNotification(for: actionResult.actionType)
            }

            // Post notifications for tool results
            if let toolResults = response.toolResults {
                for result in toolResults {
                    postRefreshNotification(for: result.toolName)
                }
            }

            // Sync reminders to EventKit if needed
            if let actionResult = response.actionResult, actionResult.success,
               actionResult.actionType == "create_reminder" {
                await syncClaraReminderToEventKit(actionResult.data)
            }

        } catch {
            isTyping = false
            self.error = error.localizedDescription

            let errorMessage = ClaraMessage(
                content: "Analysis unavailable. Protect your time today. Do not add commitments without purpose.",
                isClara: true,
                isError: true
            )
            messages.append(errorMessage)

            print("❌ Clara chat error: \(error)")
        }
    }

    /// Post refresh notifications to update relevant views after mutations
    private func postRefreshNotification(for actionType: String) {
        switch actionType {
        case "create_reminder", "complete_reminder", "delete_reminder":
            NotificationCenter.default.post(name: NSNotification.Name("RefreshReminders"), object: nil)
        case "create_task", "complete_task", "delete_task":
            NotificationCenter.default.post(name: NSNotification.Name("TaskCreated"), object: nil)
        case "create_event", "edit_event", "delete_event":
            NotificationCenter.default.post(name: NSNotification.Name("RefreshCalendar"), object: nil)
        default:
            break
        }
    }

    func startNewChat() {
        messages.removeAll()
        sessionId = nil
        inputText = ""
        error = nil
    }

    /// Syncs a Clara-created reminder to the iOS Reminders app
    private func syncClaraReminderToEventKit(_ actionData: ActionData?) async {
        guard let data = actionData else { return }

        let eventKitManager = EventKitReminderManager.shared

        // Check if authorized
        guard eventKitManager.isAuthorized else {
            print("⚠️ ClaraChat: EventKit not authorized, skipping sync")
            return
        }

        // Get reminder data - try reminders array first, then direct fields
        let reminderId: Int64
        let reminderTitle: String
        let reminderDueDate: String?
        let reminderDueTime: String?

        if let firstReminder = data.reminders?.first {
            // Reminder data in array format
            guard let id = firstReminder.id else {
                print("⚠️ ClaraChat: No reminder ID in action data, skipping EventKit sync")
                return
            }
            reminderId = id
            reminderTitle = firstReminder.title
            reminderDueDate = firstReminder.dueDate
            reminderDueTime = firstReminder.dueTime
        } else if let id = data.id, let title = data.title {
            // Reminder data in direct fields format
            reminderId = id
            reminderTitle = title
            reminderDueDate = data.dueDate ?? data.date
            reminderDueTime = data.dueTime ?? data.startTime
        } else {
            print("⚠️ ClaraChat: No reminder data found in action result")
            return
        }

        // Parse the due date
        var dueDate = Date()
        if let dateStr = reminderDueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsed = formatter.date(from: dateStr) {
                dueDate = parsed
            }
        }

        // Add time if available
        if let timeStr = reminderDueTime {
            let timeFormatter = DateFormatter()
            // Try multiple time formats
            for format in ["HH:mm:ss", "HH:mm", "h:mm a"] {
                timeFormatter.dateFormat = format
                if let parsedTime = timeFormatter.date(from: timeStr) {
                    let calendar = Calendar.current
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                    if let combined = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                                      minute: timeComponents.minute ?? 0,
                                                      second: 0,
                                                      of: dueDate) {
                        dueDate = combined
                        break
                    }
                }
            }
        }

        // Create reminder for EventKit sync
        let reminder = Reminder(
            id: reminderId,
            userId: 0,
            title: reminderTitle,
            description: nil,
            dueDate: dueDate,
            reminderTime: dueDate.addingTimeInterval(-15 * 60), // 15 min before
            isCompleted: false,
            priority: nil,
            status: .pending,
            eventId: nil,
            recurrenceRule: nil,
            snoozeUntil: nil,
            notificationEnabled: true,
            notificationSound: nil,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil
        )

        do {
            try await eventKitManager.syncReminderToEventKit(reminder)
            print("✅ ClaraChat: Synced reminder '\(reminder.title)' to iOS Reminders")
        } catch {
            print("⚠️ ClaraChat: Failed to sync to EventKit: \(error.localizedDescription)")
        }
    }
}

// MARK: - Clara Message Model
struct ClaraMessage: Identifiable {
    let id = UUID()
    var content: String
    let isClara: Bool
    let timestamp: Date = Date()
    var isError: Bool = false
    var isStreaming: Bool = false
    var statusMessage: String? = nil

    // Structured data for enhanced UI
    var insights: [ResponseInsight]?
    var contextMetrics: ContextMetrics?

    // Legacy action result (backward compat)
    var actionResult: ActionResult?

    // NEW: Multiple tool results from function calling
    var toolResults: [ToolResultForUI]?
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

                // Clara message with markdown support + structured data
                VStack(alignment: .leading, spacing: 12) {
                    // Status message during streaming
                    if let status = message.statusMessage {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(status)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.violet)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Colors.violet.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Text response bubble (show if we have content or not streaming)
                    if !message.content.isEmpty || !message.isStreaming {
                        VStack(alignment: .leading, spacing: 6) {
                            markdownText(message.content + (message.isStreaming ? "▊" : ""), isClara: true)

                            if !message.isStreaming {
                                Text(formatTime(message.timestamp))
                                    .font(.system(size: 11))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                            }
                        }
                        .padding(14)
                        .background(DesignSystem.Colors.cardBackground)
                        .clipShape(ClaraBubbleShape(isFromUser: false))
                    }

                    // Tool results (new function calling system)
                    if let toolResults = message.toolResults, !toolResults.isEmpty {
                        ForEach(Array(toolResults.enumerated()), id: \.offset) { _, result in
                            ClaraToolResultCardView(result: result)
                        }
                    }

                    // Legacy action result (backward compat)
                    if message.toolResults == nil || message.toolResults?.isEmpty == true,
                       let actionResult = message.actionResult {
                        ClaraActionResultView(actionResult: actionResult)
                    }

                    // Metrics row (if available and no action/tool results)
                    if message.actionResult == nil,
                       (message.toolResults == nil || message.toolResults?.isEmpty == true),
                       let metrics = message.contextMetrics,
                       (metrics.meetingCount ?? 0) > 0 || (metrics.freeMinutes ?? 0) > 0 {
                        ClaraMetricsRow(metrics: metrics)
                    }

                    // Insight cards (if available and no action/tool results)
                    if message.actionResult == nil,
                       (message.toolResults == nil || message.toolResults?.isEmpty == true),
                       let insights = message.insights, !insights.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(insights) { insight in
                                ClaraInsightCard(insight: insight)
                            }
                        }
                    }
                }

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

// MARK: - Animated Clara Avatar
struct ClaraAnimatedAvatar: View {
    @State private var isAnimating = false
    @State private var innerPulse = false

    private let claraGradient = LinearGradient(
        colors: [DesignSystem.Colors.violet, DesignSystem.Colors.claraPurpleLight, DesignSystem.Colors.violetDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        DesignSystem.Colors.violet.opacity(0.15 - Double(i) * 0.04),
                        lineWidth: 2
                    )
                    .frame(width: 90 + CGFloat(i) * 20, height: 90 + CGFloat(i) * 20)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .opacity(isAnimating ? 0.0 : 1.0)
                    .animation(
                        Animation.easeOut(duration: 2.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.4),
                        value: isAnimating
                    )
            }

            // Main avatar circle
            Circle()
                .fill(claraGradient)
                .frame(width: 88, height: 88)
                .shadow(color: DesignSystem.Colors.violet.opacity(0.5), radius: 20, y: 8)
                .scaleEffect(innerPulse ? 1.03 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: innerPulse
                )

            // Inner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.3), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 88, height: 88)

            // Sparkle icon
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.3), radius: 4)
        }
        .onAppear {
            isAnimating = true
            innerPulse = true
        }
    }
}

// MARK: - Enhanced Suggested Prompt Button
struct EnhancedSuggestedPromptButton: View {
    let prompt: String
    let action: () -> Void

    private var promptCategory: (icon: String, color: Color, bgColor: Color) {
        let lowercased = prompt.lowercased()
        if lowercased.contains("sleep") || lowercased.contains("rest") {
            return ("moon.stars.fill", DesignSystem.Colors.indigo, DesignSystem.Colors.indigo.opacity(0.12))
        }
        if lowercased.contains("productive") || lowercased.contains("focus") || lowercased.contains("deep work") {
            return ("target", DesignSystem.Colors.amber, DesignSystem.Colors.amber.opacity(0.12))
        }
        if lowercased.contains("schedule") || lowercased.contains("calendar") || lowercased.contains("meeting") {
            return ("calendar", DesignSystem.Colors.blue, DesignSystem.Colors.blue.opacity(0.12))
        }
        if lowercased.contains("balance") || lowercased.contains("life") {
            return ("scale.3d", DesignSystem.Colors.info, DesignSystem.Colors.info.opacity(0.12))
        }
        if lowercased.contains("pattern") || lowercased.contains("trend") {
            return ("chart.line.uptrend.xyaxis", DesignSystem.Colors.emerald, DesignSystem.Colors.emerald.opacity(0.12))
        }
        if lowercased.contains("energy") || lowercased.contains("tired") {
            return ("bolt.fill", DesignSystem.Colors.amber, DesignSystem.Colors.amber.opacity(0.12))
        }
        if lowercased.contains("today") || lowercased.contains("overview") {
            return ("sun.max.fill", DesignSystem.Colors.amber, DesignSystem.Colors.amber.opacity(0.12))
        }
        return ("sparkles", DesignSystem.Colors.violet, DesignSystem.Colors.violet.opacity(0.12))
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Category icon with background
                ZStack {
                    Circle()
                        .fill(promptCategory.bgColor)
                        .frame(width: 40, height: 40)

                    Image(systemName: promptCategory.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(promptCategory.color)
                }

                // Prompt text
                Text(prompt)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(promptCategory.color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PromptButtonStyle())
    }
}

// MARK: - Prompt Button Style (with press effect)
struct PromptButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ClaraChatView()
        .preferredColorScheme(.dark)
}
