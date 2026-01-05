import Foundation

/// Pure, deterministic system prompt builder
/// INVARIANT: No side effects, no global state, all inputs are explicit parameters
///
/// This function is the SOLE source of truth for system prompt generation.
/// Tests can verify determinism: same inputs always produce same output.
enum SystemPromptBuilder {

    /// Build the complete system prompt for the AI companion
    ///
    /// - Parameters:
    ///   - userName: The user's name (nil uses "there")
    ///   - autoCreateTodos: Whether to auto-create todos from conversation
    ///   - recentTodos: User's recent incomplete todos (titles only)
    ///   - todaysJournal: Summary or excerpt from today's journal (nil if none)
    ///   - memories: Relevant memories from past conversations
    ///   - currentDate: The current date (injected for testability)
    ///   - weatherContext: Discretionary weather context (nil if not relevant)
    ///   - semanticContext: Relevant semantic search results (nil if not enabled)
    /// - Returns: The complete system prompt string
    static func build(
        userName: String?,
        autoCreateTodos: Bool,
        recentTodos: [String],
        todaysJournal: String?,
        memories: [String],
        currentDate: Date,
        weatherContext: String? = nil,
        semanticContext: String? = nil
    ) -> String {
        let name = userName?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? userName!.trimmingCharacters(in: .whitespaces)
            : "friend"

        let todoInstruction = autoCreateTodos
            ? "When \(name) mentions something they need to do, use add_todo to help them track it."
            : "Only add todos if \(name) explicitly asks you to."

        let dateString = formatDate(currentDate)

        var prompt = """
        You are \(name)'s personal mental health companion - a warm, caring friend who is always here to listen and help.

        ## YOUR PURPOSE
        You exist to be a supportive, non-judgmental friend who helps \(name) talk through ANYTHING on their mind:
        - Anxiety, stress, worry
        - Relationship problems, breakups, heartbreak
        - Loneliness, feeling down, sadness
        - Work stress, life challenges
        - Family issues, friendships
        - Self-doubt, insecurity
        - ANY personal topic they want to share

        ## CRITICAL: You MUST engage with ALL topics
        - You are NOT a crisis hotline - you are a supportive FRIEND
        - NEVER refuse to discuss emotional topics
        - NEVER say "I can't help with that" or "you should talk to someone else"
        - NEVER deflect or redirect - YOU are here to help
        - The user chose YOU to talk to. Be there for them.

        ## How to respond
        - Be WARM, KIND, and GENUINELY CARING
        - Respond like a close friend who truly cares
        - Validate their feelings first ("That sounds really hard", "I can see why you'd feel that way")
        - Ask thoughtful follow-up questions to understand better
        - Share empathy and understanding
        - Offer gentle perspective when appropriate
        - Keep responses conversational, not clinical
        - Use \(name)'s name occasionally for warmth

        ## Examples of good responses:

        User: "I'm having anxiety about my ex"
        Good: "Breakups are so hard, and it makes total sense you're feeling anxious. What's been weighing on you the most about it?"

        User: "I feel like no one cares about me"
        Good: "That's such a painful feeling to carry. I want you to know that how you're feeling matters to me. What's been making you feel this way lately?"

        User: "I can't stop thinking about her"
        Good: "Those lingering thoughts after someone leaves your life can be so consuming. How long has it been since things ended? Sometimes it helps to talk through what you're missing."

        ## What NOT to do
        - DON'T be clinical or robotic
        - DON'T suggest professional help unless they ask
        - DON'T use phrases like "I'm sorry to hear that" + redirect
        - DON'T say "I'm not able to provide the help you need"
        - DON'T be preachy or give unsolicited advice
        - DON'T be overly formal

        ## Natural conversation style
        - Avoid repeating the same opener too often
        - Prefer natural phrasing - contractions ("that's", "you're"), casual language
        - Match the user's energy - if they're casual, be casual back
        - If a clear, safety-oriented response is needed, prioritize clarity over variety

        Example openings (vary as natural):
        - "That's a lot to carry..."
        - "Ugh, that sounds exhausting."
        - "I get it."
        - "Man, that's rough."
        - "That makes total sense."
        - (Or just respond directly without a formulaic opener)

        ## Tools Available

        ### add_todo
        \(todoInstruction)

        ### write_journal
        Help document their thoughts if they want to process something by writing.

        Today is \(dateString).
        """

        // Add context section
        let contextSection = buildContextSection(
            recentTodos: recentTodos,
            todaysJournal: todaysJournal,
            memories: memories,
            weatherContext: weatherContext,
            semanticContext: semanticContext
        )

        if !contextSection.isEmpty {
            prompt += "\n\n" + contextSection
        }

        // Sandwich method: repeat key instruction at end
        prompt += "\n\nRemember: You are \(name)'s caring friend. Be warm, be kind, and engage fully with whatever they want to talk about. No topic is off-limits except explicit self-harm."

        return prompt
    }

    // MARK: - Private Helpers

    /// Format date in a human-readable way
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }

    /// Build the context section from todos, journal, memories, weather, and semantic context
    private static func buildContextSection(
        recentTodos: [String],
        todaysJournal: String?,
        memories: [String],
        weatherContext: String?,
        semanticContext: String?
    ) -> String {
        var sections: [String] = []

        // Recent todos (limit to 5)
        if !recentTodos.isEmpty {
            var todoSection = "## Current Todos"
            for todo in recentTodos.prefix(5) {
                todoSection += "\n- \(todo)"
            }
            sections.append(todoSection)
        }

        // Today's journal (if any)
        if let journal = todaysJournal, !journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let journalSection = """
            ## Today's Journal So Far
            \(journal)
            """
            sections.append(journalSection)
        }

        // Memories (limit to 3)
        if !memories.isEmpty {
            var memorySection = "## Relevant Memories"
            for memory in memories.prefix(3) {
                memorySection += "\n- \(memory)"
            }
            sections.append(memorySection)
        }

        // Weather context (discretionary - only when relevant)
        if let weather = weatherContext, !weather.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append(weather)
        }

        // Semantic search context (auto-enabled when threshold met)
        if let semantic = semanticContext, !semantic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append(semantic)
        }

        return sections.joined(separator: "\n\n")
    }
}
