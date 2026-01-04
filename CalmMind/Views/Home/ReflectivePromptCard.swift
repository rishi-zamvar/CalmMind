import SwiftUI

/// AI invitation card with warm, personalized prompts
/// Caches prompt once per day, never exposes sensitive details
/// When privacy mode is on: shows fallback only, no network calls, no refresh button
struct ReflectivePromptCard: View {
    @AppStorage("privacyModeEnabled") private var privacyModeEnabled = false
    @AppStorage("cachedPrompt") private var cachedPrompt = ""
    @AppStorage("promptCacheDate") private var promptCacheDateString = ""

    @State private var promptState: PromptState = .loading
    @State private var isRefreshing = false

    let onTap: () -> Void
    let generatePrompt: () async -> String?

    var body: some View {
        AmbientCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header with refresh button (hidden when privacy mode is on)
                HStack {
                    CardHeader(title: WarmCopy.promptCardTitle)
                    Spacer()
                    // Hide refresh button in privacy mode (no network calls)
                    if !privacyModeEnabled {
                        refreshButton
                    }
                }

                // Prompt content
                promptContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityIdentifier("reflectivePromptCard")
        .accessibilityHint("Tap to start a chat")
        .task {
            await loadPrompt()
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var promptContent: some View {
        switch promptState {
        case .loading:
            PromptShimmer()
                .padding(.vertical, 4)

        case .success(let prompt):
            Text("\"\(prompt)\"")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

        case .error:
            Text("\"\(WarmCopy.promptFallback)\"")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    private var refreshButton: some View {
        Button(action: {
            Task { await refreshPrompt() }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(
                    isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                    value: isRefreshing
                )
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
    }

    // MARK: - Logic

    private func loadPrompt() async {
        // Check if privacy mode is on - show fallback only, no network calls
        if privacyModeEnabled {
            promptState = .success(WarmCopy.promptFallback)
            return
        }

        // Check if we have a valid cached prompt for today
        let today = Calendar.current.startOfDay(for: Date())
        let todayString = ISO8601DateFormatter().string(from: today)

        if promptCacheDateString == todayString, !cachedPrompt.isEmpty {
            promptState = .success(cachedPrompt)
            return
        }

        // Generate new prompt
        await generateNewPrompt()
    }

    private func refreshPrompt() async {
        isRefreshing = true
        promptState = .loading

        // Clear cache
        cachedPrompt = ""
        promptCacheDateString = ""

        await generateNewPrompt()
        isRefreshing = false
    }

    private func generateNewPrompt() async {
        promptState = .loading

        // Timeout after 4 seconds
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 4_000_000_000)
            return nil as String?
        }

        let generateTask = Task {
            await generatePrompt()
        }

        // Race between timeout and generation
        let result: String?
        do {
            result = try await withTaskGroup(of: String?.self) { group in
                group.addTask { try? await timeoutTask.value }
                group.addTask { await generateTask.value }

                for await value in group {
                    if value != nil {
                        group.cancelAll()
                        return value
                    }
                }
                return nil
            }
        }

        if let prompt = result, !prompt.isEmpty {
            // Cache the result
            let today = Calendar.current.startOfDay(for: Date())
            promptCacheDateString = ISO8601DateFormatter().string(from: today)
            cachedPrompt = prompt
            promptState = .success(prompt)
        } else {
            promptState = .error
        }
    }
}

// MARK: - Prompt State

enum PromptState {
    case loading
    case success(String)
    case error  // Shows fallback, NOT error message
}

#Preview {
    VStack(spacing: 20) {
        ReflectivePromptCard(
            onTap: {},
            generatePrompt: {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return "You've had a lot going on with study abroad planning. Want to talk through what feels heaviest today?"
            }
        )
    }
    .padding()
    .ambientBackground()
}
