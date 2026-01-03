import SwiftUI
import SwiftData

/// Main journal list view
struct JournalListView: View {
    @Bindable var viewModel: JournalViewModel
    @State private var selectedEntry: JournalEntry?
    @State private var showingNewEntry: Bool = false

    var body: some View {
        Group {
            if viewModel.hasEntries {
                List {
                    ForEach(viewModel.entriesByMonth, id: \.month) { group in
                        Section(group.month) {
                            ForEach(group.entries) { entry in
                                JournalEntryRow(entry: entry)
                                    .onTapGesture {
                                        selectedEntry = entry
                                    }
                            }
                            .onDelete { indexSet in
                                Task {
                                    for index in indexSet {
                                        await viewModel.deleteEntry(group.entries[index])
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView(
                    "No Journal Entries",
                    systemImage: "book.closed",
                    description: Text("Start writing to reflect on your day")
                )
            }
        }
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewEntry = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                JournalDetailView(entry: entry, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NavigationStack {
                JournalEditorView(viewModel: viewModel, isPresented: $showingNewEntry)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .task {
            await viewModel.loadEntries()
        }
    }
}

/// Row for a single journal entry
struct JournalEntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(entry.entryDate))
                    .font(.headline)

                Spacer()

                if let mood = entry.moodScore {
                    MoodBadge(score: mood)
                }
            }

            Text(entry.summary ?? entry.fullText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

/// Badge showing mood score
struct MoodBadge: View {
    let score: Int

    private var moodColor: Color {
        switch score {
        case 1...3: return .red
        case 4...6: return .orange
        case 7...8: return .yellow
        case 9...10: return .green
        default: return .gray
        }
    }

    var body: some View {
        Text("\(score)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(moodColor)
            .clipShape(Circle())
    }
}

#Preview {
    Text("Journal List Preview")
}
