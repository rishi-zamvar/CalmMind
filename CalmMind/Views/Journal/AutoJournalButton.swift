import SwiftUI

/// Button to trigger on-demand journal synthesis
/// Shows progress while synthesizing, then mood result
struct AutoJournalButton: View {
    let entry: JournalEntry
    let onSynthesize: () async -> (text: String, mood: Int)?

    @State private var isSynthesizing = false
    @State private var showSuccess = false

    var body: some View {
        Button {
            synthesize()
        } label: {
            HStack(spacing: 6) {
                if isSynthesizing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Writing...")
                } else if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Colors.sage)
                    Text("Saved")
                } else {
                    Image(systemName: "sparkles")
                    Text(entry.isSynthesized ? "Rewrite" : "Auto Journal")
                }
            }
            .font(DesignTokens.Typography.body)
            .foregroundColor(DesignTokens.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignTokens.Colors.subtleSection)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.button))
        }
        .disabled(isSynthesizing || entry.includedEvents.isEmpty)
    }

    private func synthesize() {
        isSynthesizing = true
        Task {
            _ = await onSynthesize()
            isSynthesizing = false
            showSuccess = true
        }
    }

}
