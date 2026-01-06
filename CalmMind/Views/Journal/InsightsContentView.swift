import SwiftUI

/// Displays AI-generated insights (patterns and suggestions)
struct InsightsContentView: View {
    let insights: JournalInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Patterns section
            if !insights.patterns.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Patterns", systemImage: "chart.line.uptrend.xyaxis")
                        .font(DesignTokens.Typography.meta.bold())
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    ForEach(insights.patterns, id: \.self) { pattern in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(DesignTokens.Colors.warmClay)
                                .frame(width: 6, height: 6)
                                .offset(y: 6)
                            Text(pattern)
                                .font(DesignTokens.Typography.body)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                        }
                    }
                }
            }

            // Suggestions section
            if !insights.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Try This", systemImage: "hand.point.right")
                        .font(DesignTokens.Typography.meta.bold())
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    ForEach(insights.suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.Colors.sage)
                                .offset(y: 2)
                            Text(suggestion)
                                .font(DesignTokens.Typography.body)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                        }
                    }
                }
            }

            // Empty state
            if insights.patterns.isEmpty && insights.suggestions.isEmpty {
                Text("No insights available for this entry")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .italic()
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    InsightsContentView(insights: JournalInsights(
        patterns: ["You mention work stress frequently", "Social activities improve your mood"],
        suggestions: ["Try 4-7-8 breathing before bed", "Take a short walk during lunch"],
        inputHash: "preview",
        providerModel: "preview",
        generatedAt: Date()
    ))
    .padding()
}
