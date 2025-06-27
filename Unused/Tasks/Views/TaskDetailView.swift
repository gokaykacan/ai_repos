import SwiftUI

struct TaskDetailView: View {
    @StateObject var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                
                categorySection
                
                dueDateSection
                
                prioritySection
                
                if viewModel.isEditing {
                    subtasksSection
                }
                
                notesSection
            }
            .navigationTitle(viewModel.isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            let success = await viewModel.save()
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isLoading)
                }
            }
            .disabled(viewModel.isLoading)
            .onAppear {
                if !viewModel.isEditing {
                    titleFieldFocused = true
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        Section {
            TextField("Task title", text: $viewModel.title)
                .focused($titleFieldFocused)
                .font(.body)
        }
    }
    
    private var categorySection: some View {
        Section("Category") {
            Button(action: { viewModel.showingCategoryPicker = true }) {
                HStack {
                    if let category = viewModel.selectedCategory {
                        Image(systemName: category.icon ?? "folder")
                            .foregroundColor(category.color)
                        
                        Text(category.name ?? "Unnamed Category")
                            .foregroundColor(.label)
                    } else {
                        Text("Select Category")
                            .foregroundColor(.secondaryLabel)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.tertiaryLabel)
                        .font(.caption)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingCategoryPicker) {
            CategoryPickerView(
                categories: viewModel.categories,
                selectedCategory: $viewModel.selectedCategory
            )
        }
    }
    
    private var dueDateSection: some View {
        Section("Due Date") {
            Toggle("Set due date", isOn: $viewModel.hasDueDate)
                .onChange(of: viewModel.hasDueDate) { _ in
                    viewModel.toggleDueDate()
                }
            
            if viewModel.hasDueDate {
                DatePicker(
                    "Due date",
                    selection: Binding(
                        get: { viewModel.dueDate ?? Date() },
                        set: { viewModel.dueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
    }
    
    private var prioritySection: some View {
        Section("Priority") {
            Picker("Priority", selection: $viewModel.priority) {
                ForEach(TaskPriority.allCases) { priority in
                    HStack {
                        Image(systemName: priority.systemImage)
                            .foregroundColor(priority.color)
                        Text(priority.title)
                    }
                    .tag(priority)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var subtasksSection: some View {
        Section("Subtasks") {
            ForEach(viewModel.subtasks) { subtask in
                HStack {
                    Button(action: { viewModel.toggleSubtaskCompletion(subtask) }) {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(subtask.isCompleted ? .green : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(subtask.title ?? "Untitled Subtask")
                        .strikethrough(subtask.isCompleted)
                        .foregroundColor(subtask.isCompleted ? .secondaryLabel : .label)
                    
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        viewModel.deleteSubtask(subtask)
                    }
                }
            }
            
            HStack {
                TextField("Add subtask", text: $viewModel.newSubtaskTitle)
                    .onSubmit {
                        viewModel.addSubtask()
                    }
                
                Button("Add") {
                    viewModel.addSubtask()
                }
                .disabled(viewModel.newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextField("Add notes...", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}

struct CategoryPickerView: View {
    let categories: [TaskCategory]
    @Binding var selectedCategory: TaskCategory?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button("None") {
                        selectedCategory = nil
                        dismiss()
                    }
                    .foregroundColor(.label)
                }
                
                Section("Categories") {
                    ForEach(categories) { category in
                        Button(action: {
                            selectedCategory = category
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: category.icon ?? "folder")
                                    .foregroundColor(category.color)
                                
                                Text(category.name ?? "Unnamed Category")
                                    .foregroundColor(.label)
                                
                                Spacer()
                                
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let container = DependencyContainer()
        TaskDetailView(viewModel: container.makeTaskDetailViewModel())
    }
}