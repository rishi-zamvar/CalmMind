import SwiftUI

/// Detail view for a journal entry
struct JournalDetailView: View {
    let entry: JournalEntry
    @Bindable var viewModel: JournalViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing: Bool = false
    @State private var editedText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Date header
                HStack {
                    VStack(alignment: .leading) {
                        Text(formatDate(entry.entryDate))
                            .font(DesignTokens.Typography.sectionHeader)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text(formatWeekday(entry.entryDate))
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Spacer()

                    // Mood picker
                    MoodPicker(
                        selectedMood: entry.moodScore,
                        onSelect: { score in
                            Task {
                                await viewModel.setMoodScore(entry, score: score)
                            }
                        }
                    )
                }
                .padding(.horizontal)

                // Entry content (paper feel)
                if isEditing {
                    TextEditor(text: $editedText)
                        .font(DesignTokens.Typography.body)
                        .frame(minHeight: 200)
                        .padding()
                        .background(DesignTokens.Colors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.card))
                        .cardShadow()
                        .padding(.horizontal)
                } else {
                    Text(entry.displayText.isEmpty ? "What's on your mind today?" : entry.displayText)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(entry.displayText.isEmpty ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.textPrimary)
                        .italic(entry.displayText.isEmpty)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignTokens.Colors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.card))
                        .cardShadow()
                        .padding(.horizontal)
                }

                // Auto-journaling events section (if any)
                if !entry.events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Captured Moments")
                            .font(DesignTokens.Typography.sectionHeader)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        ForEach(entry.includedEvents.sorted { $0.timestamp < $1.timestamp }) { event in
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.userText)
                                        .font(DesignTokens.Typography.body)
                                        .foregroundColor(DesignTokens.Colors.textPrimary)
                                    Text(formatTime(event.timestamp))
                                        .font(DesignTokens.Typography.meta)
                                        .foregroundColor(DesignTokens.Colors.textTertiary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(DesignTokens.Colors.subtleSection)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.card))
                    .padding(.horizontal)
                }

                // Summary if available
                if let summary = entry.summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(DesignTokens.Typography.sectionHeader)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Text(summary)
                            .font(DesignTokens.Typography.body)
                            .italic()
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }
                    .padding()
                    .background(DesignTokens.Colors.subtleSection)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.card))
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
        }
        .ambientBackground()
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Done") {
                        Task {
                            await viewModel.updateEntry(entry, text: editedText)
                            isEditing = false
                        }
                    }
                    .foregroundColor(DesignTokens.Colors.warmClay)
                } else {
                    Button("Edit") {
                        editedText = entry.fullText
                        isEditing = true
                    }
                    .foregroundColor(DesignTokens.Colors.warmClay)
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                    }
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                } else {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Mood score picker (warm styling)
struct MoodPicker: View {
    let selectedMood: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(1...10, id: \.self) { score in
                Button {
                    onSelect(score)
                } label: {
                    HStack {
                        Text("\(score)")
                        Text(moodEmoji(for: score))
                        if selectedMood == score {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                if let mood = selectedMood {
                    Text(moodEmoji(for: mood))
                    Text("\(mood)")
                        .font(DesignTokens.Typography.body)
                } else {
                    Text("Set Mood")
                        .font(DesignTokens.Typography.body)
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundColor(DesignTokens.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignTokens.Colors.subtleSection)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.button))
        }
    }

    private func moodEmoji(for score: Int) -> String {
        switch score {
        case 1...2: return "😢"
        case 3...4: return "😕"
        case 5...6: return "😐"
        case 7...8: return "🙂"
        case 9...10: return "😊"
        default: return "😐"
        }
    }
}

/// Editor for creating new journal entries (warm paper feel)
struct JournalEditorView: View {
    @Bindable var viewModel: JournalViewModel
    @Binding var isPresented: Bool
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How was your day?")
                .font(DesignTokens.Typography.sectionHeader)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal)

            TextEditor(text: $text)
                .font(DesignTokens.Typography.body)
                .focused($isFocused)
                .frame(minHeight: 200)
                .padding()
                .scrollContentBackground(.hidden)
                .background(DesignTokens.Colors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.card))
                .cardShadow()
                .padding(.horizontal)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What's on your mind today?")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .italic()
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }

            Spacer()
        }
        .padding(.top)
        .ambientBackground()
        .navigationTitle("New Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    Task {
                        await viewModel.createEntry(text: text)
                        isPresented = false
                    }
                }
                .foregroundColor(DesignTokens.Colors.warmClay)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    Text("Journal Detail Preview")
}
