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
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(formatWeekday(entry.entryDate))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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

                Divider()

                // Entry content
                if isEditing {
                    TextEditor(text: $editedText)
                        .frame(minHeight: 200)
                        .padding(.horizontal)
                } else {
                    Text(entry.fullText)
                        .padding(.horizontal)
                }

                // Summary if available
                if let summary = entry.summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(summary)
                            .font(.subheadline)
                            .italic()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
        }
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
                } else {
                    Button("Edit") {
                        editedText = entry.fullText
                        isEditing = true
                    }
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                    }
                } else {
                    Button("Close") {
                        dismiss()
                    }
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
}

/// Mood score picker
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
                } else {
                    Text("Set Mood")
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
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

/// Editor for creating new journal entries
struct JournalEditorView: View {
    @Bindable var viewModel: JournalViewModel
    @Binding var isPresented: Bool
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How was your day?")
                .font(.headline)
                .padding(.horizontal)

            TextEditor(text: $text)
                .focused($isFocused)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
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
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
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
