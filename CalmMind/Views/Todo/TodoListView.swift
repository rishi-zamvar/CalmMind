import SwiftUI
import SwiftData

/// Main todo list view
struct TodoListView: View {
    @Bindable var viewModel: TodoViewModel
    @State private var showCompleted: Bool = false
    @FocusState private var isAddFieldFocused: Bool

    /// Set to true when navigating from "Add task" CTA
    var autoFocusAdd: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Add todo input
            AddTodoBar(
                text: $viewModel.newTodoTitle,
                canAdd: viewModel.canAdd,
                isFocused: $isAddFieldFocused,
                onAdd: {
                    Task {
                        await viewModel.addTodo()
                    }
                }
            )

            // Todo lists
            List {
                // Incomplete section
                if !viewModel.incompleteTodos.isEmpty {
                    Section {
                        ForEach(viewModel.incompleteTodos) { todo in
                            TodoRow(
                                todo: todo,
                                onToggle: {
                                    Task {
                                        await viewModel.completeTodo(todo)
                                    }
                                }
                            )
                            .listRowBackground(DesignTokens.Colors.elevatedSurface)
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    await viewModel.deleteTodo(viewModel.incompleteTodos[index])
                                }
                            }
                        }
                    } header: {
                        Text("To Do")
                            .font(DesignTokens.Typography.sectionHeader)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }
                }

                // Completed section (collapsed by default)
                if !viewModel.completedTodos.isEmpty {
                    Section {
                        if showCompleted {
                            ForEach(viewModel.completedTodos) { todo in
                                TodoRow(
                                    todo: todo,
                                    onToggle: {
                                        Task {
                                            await viewModel.uncompleteTodo(todo)
                                        }
                                    }
                                )
                                .listRowBackground(DesignTokens.Colors.elevatedSurface)
                            }
                            .onDelete { indexSet in
                                Task {
                                    for index in indexSet {
                                        await viewModel.deleteTodo(viewModel.completedTodos[index])
                                    }
                                }
                            }
                        }
                    } header: {
                        Button {
                            withAnimation(DesignTokens.defaultAnimation) {
                                showCompleted.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Completed (\(viewModel.completedTodos.count))")
                                    .font(DesignTokens.Typography.sectionHeader)
                                Spacer()
                                Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }

                // Empty state - warm copy
                if viewModel.incompleteTodos.isEmpty && viewModel.completedTodos.isEmpty {
                    VStack(spacing: 12) {
                        Text(WarmCopy.emptyTodosTab)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .ambientBackground()
        .navigationTitle("Todos")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? WarmCopy.offlineError)
        }
        .task {
            await viewModel.loadTodos()
        }
        .onAppear {
            if autoFocusAdd {
                // Delay to ensure view is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAddFieldFocused = true
                }
            }
        }
    }
}

/// Input bar for adding new todos
struct AddTodoBar: View {
    @Binding var text: String
    let canAdd: Bool
    var isFocused: FocusState<Bool>.Binding
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Add a gentle task...", text: $text)
                .font(DesignTokens.Typography.body)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(DesignTokens.Colors.subtleSection)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.button))
                .focused(isFocused)
                .onSubmit {
                    if canAdd {
                        onAdd()
                    }
                }

            Button(action: {
                DesignTokens.Haptics.softTap()
                onAdd()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canAdd ? DesignTokens.Colors.warmClay : DesignTokens.Colors.textTertiary)
            }
            .disabled(!canAdd)
            .animation(DesignTokens.defaultAnimation, value: canAdd)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenPad)
        .padding(.vertical, DesignTokens.Spacing.rowPadV)
        .background(DesignTokens.Colors.appBackground)
    }
}

#Preview {
    Text("Todo List Preview")
}
