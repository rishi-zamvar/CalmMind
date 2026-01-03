import SwiftUI
import SwiftData

/// Main todo list view
struct TodoListView: View {
    @Bindable var viewModel: TodoViewModel
    @State private var showCompleted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Add todo input
            AddTodoBar(
                text: $viewModel.newTodoTitle,
                canAdd: viewModel.canAdd,
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
                    }
                }

                // Completed section
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
                            withAnimation {
                                showCompleted.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Completed (\(viewModel.completedTodos.count))")
                                Spacer()
                                Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }

                // Empty state
                if viewModel.incompleteTodos.isEmpty && viewModel.completedTodos.isEmpty {
                    ContentUnavailableView(
                        "No Todos",
                        systemImage: "checkmark.circle",
                        description: Text("Add a todo to get started")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Todos")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .task {
            await viewModel.loadTodos()
        }
    }
}

/// Input bar for adding new todos
struct AddTodoBar: View {
    @Binding var text: String
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Add a todo...", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if canAdd {
                        onAdd()
                    }
                }

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(canAdd ? .blue : .gray)
            }
            .disabled(!canAdd)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview {
    Text("Todo List Preview")
}
