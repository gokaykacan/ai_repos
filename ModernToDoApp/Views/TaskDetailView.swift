import SwiftUI
import CoreData
import Foundation
import UserNotifications

struct TaskDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var notes: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    @State private var selectedCategory: TaskCategory?
    @State private var showingDatePicker = false
    @State private var showingCategoryPicker = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    let task: Task?
    let isEditing: Bool
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskCategory.name, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<TaskCategory>
    
    init(task: Task? = nil) {
        self.task = task
        self.isEditing = task != nil
        
        // Initialize state from task or defaults
        self._title = State(initialValue: task?.title ?? "")
        self._notes = State(initialValue: task?.notes ?? "")
        self._priority = State(initialValue: TaskPriority(rawValue: Int(task?.priority ?? 1)) ?? .medium)
        self._dueDate = State(initialValue: task?.dueDate)
        self._hasDueDate = State(initialValue: task?.dueDate != nil)
        self._selectedCategory = State(initialValue: task?.category)
    }
    
    var body: some View {
        NavigationView {
            Form {
                titleSection
                notesSection
                prioritySection
                dueDateSection
                categorySection
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var titleSection: some View {
        Section("Title") {
            TextField("Enter task title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            if #available(iOS 16.0, *) {
                TextField("Add notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField("Add notes (optional)", text: $notes)
                    .lineLimit(6)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    private var prioritySection: some View {
        Section("Priority") {
            Picker("Select Priority", selection: $priority) {
                ForEach(TaskPriority.allCases, id: \.rawValue) { priorityLevel in
                    HStack {
                        Image(systemName: priorityLevel.systemImage)
                            .foregroundColor(priorityLevel.color)
                        Text(priorityLevel.title)
                    }
                    .tag(priorityLevel)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    private var dueDateSection: some View {
        Section("Due Date") {
            Toggle("Set due date", isOn: $hasDueDate)
                .onChange(of: hasDueDate) { enabled in
                    if enabled && dueDate == nil {
                        dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                    } else if !enabled {
                        dueDate = nil
                    }
                }
            
            if hasDueDate {
                DatePicker(
                    "Due date",
                    selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
    }
    
    private var categorySection: some View {
        Section("Category") {
            if categories.isEmpty {
                Button("Create First Category") {
                    createDefaultCategory()
                }
                .foregroundColor(.blue)
            } else {
                Picker("Category", selection: $selectedCategory) {
                    Text("None").tag(nil as TaskCategory?)
                    
                    ForEach(categories, id: \.self) { category in
                        HStack {
                            Circle()
                                .fill(Color(hex: category.colorHex ?? "#007AFF"))
                                .frame(width: 12, height: 12)
                            Text(category.name ?? "Unnamed")
                        }
                        .tag(category as TaskCategory?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    private func saveTask() {
        withAnimation {
            let taskToSave: Task
            
            if let existingTask = task {
                // Update existing task
                existingTask.title = title
                existingTask.notes = notes.isEmpty ? nil : notes
                existingTask.priority = Int16(priority.rawValue)
                existingTask.dueDate = hasDueDate ? dueDate : nil
                existingTask.category = selectedCategory
                existingTask.updatedAt = Date()
                taskToSave = existingTask
            } else {
                // Create new task
                let newTask = Task(context: viewContext)
                newTask.title = title
                newTask.notes = notes.isEmpty ? nil : notes
                newTask.priority = Int16(priority.rawValue)
                newTask.dueDate = hasDueDate ? dueDate : nil
                newTask.category = selectedCategory
                newTask.id = UUID()
                newTask.createdAt = Date()
                newTask.updatedAt = Date()
                newTask.isCompleted = false
                taskToSave = newTask
            }
            
            do {
                try viewContext.save()
                
                // Schedule notification if enabled and task has due date
                if notificationsEnabled {
                    if hasDueDate && dueDate != nil && !taskToSave.isCompleted {
                        NotificationManager.shared.scheduleNotification(for: taskToSave)
                    } else {
                        // Cancel notification if due date was removed or task completed
                        NotificationManager.shared.cancelNotification(for: taskToSave)
                    }
                }
                
                dismiss()
            } catch {
                print("Error saving task: \(error)")
            }
        }
    }
    
    private func createDefaultCategory() {
        withAnimation {
            let category = TaskCategory(context: viewContext)
            category.id = UUID()
            category.name = "Personal"
            category.colorHex = "#007AFF"
            category.icon = "person"
            category.createdAt = Date()
            category.sortOrder = 0
            
            do {
                try viewContext.save()
            } catch {
                print("Error creating default category: \(error)")
            }
        }
    }
}

struct TaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TaskDetailView()
            .environment(\.managedObjectContext, CoreDataStack.shared.container.viewContext)
    }
}