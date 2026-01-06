import SwiftUI
import SwiftData

/// Main journal list view
struct JournalListView: View {
    @Bindable var viewModel: JournalViewModel
    let userPreferences: UserPreferences
    @State private var selectedEntry: JournalEntry?
    @State private var showingNewEntry: Bool = false

    var body: some View {
        contentView
            .ambientBackground()
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    newEntryButton
                }
            }
            .sheet(item: $selectedEntry) { entry in
                NavigationStack {
                    JournalDetailView(entry: entry, viewModel: viewModel, userPreferences: userPreferences)
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
                Text(viewModel.errorMessage ?? WarmCopy.offlineError)
            }
            .task {
                await viewModel.loadEntries()
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.hasEntries {
            entriesList
        } else {
            emptyState
        }
    }

    private var entriesList: some View {
        List {
            ForEach(viewModel.entriesByMonth, id: \.month) { group in
                Section {
                    ForEach(group.entries) { entry in
                        JournalEntryRow(entry: entry)
                            .onTapGesture {
                                selectedEntry = entry
                            }
                            .listRowBackground(DesignTokens.Colors.elevatedSurface)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await viewModel.deleteEntry(group.entries[index])
                            }
                        }
                    }
                } header: {
                    sectionHeader(group.month)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(WarmCopy.noJournalEntries)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var newEntryButton: some View {
        Button {
            showingNewEntry = true
        } label: {
            Image(systemName: "square.and.pencil")
                .foregroundColor(DesignTokens.Colors.warmClay)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignTokens.Typography.sectionHeader)
            .foregroundColor(DesignTokens.Colors.textPrimary)
    }
}

/// Row for a single journal entry
struct JournalEntryRow: View {
    let entry: JournalEntry

    /// Preview text for the row - prefers summary, then synthesized, then events
    private var previewText: String {
        if let summary = entry.summary, !summary.isEmpty {
            return summary
        }
        if !entry.fullText.isEmpty {
            return entry.fullText
        }
        // Auto-journaling: show synthesized or first event
        if let synthesized = entry.synthesizedText, !synthesized.isEmpty {
            return synthesized
        }
        if let firstEvent = entry.includedEvents.first {
            let eventCount = entry.includedEvents.count
            if eventCount > 1 {
                return "\(firstEvent.userText) (+\(eventCount - 1) more)"
            }
            return firstEvent.userText
        }
        return "Empty entry"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDate(entry.entryDate))
                .font(DesignTokens.Typography.sectionHeader)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text(previewText)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
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

#Preview {
    Text("Journal List Preview")
}
