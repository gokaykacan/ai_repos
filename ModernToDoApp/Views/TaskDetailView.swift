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
    @State private var dueDate: Date? {
        didSet {
            hasDueDate = (dueDate != nil)
        }
    }
    @State private var hasDueDate: Bool
    @State private var selectedCategory: TaskCategory?
    @State private var recurrenceType: RecurrenceType
    @State private var showingDatePicker = false
    @State private var showingCategoryPicker = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    let task: Task?
    let isEditing: Bool
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskCategory.name, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<TaskCategory>
    
    init(task: Task? = nil, category: TaskCategory? = nil) {
        self.task = task
        self.isEditing = task != nil
        
        // Initialize state from task or defaults
        self._title = State(initialValue: task?.title ?? "")
        self._notes = State(initialValue: task?.notes ?? "")
        self._priority = State(initialValue: TaskPriority(rawValue: Int(task?.priority ?? 1)) ?? .medium)
        self._dueDate = State(initialValue: task?.dueDate)
        self._hasDueDate = State(initialValue: task?.dueDate != nil)
        self._recurrenceType = State(initialValue: task?.recurrenceTypeEnum ?? .none)
        // If editing, use the task's category. If creating, use the passed category.
        self._selectedCategory = State(initialValue: task?.category ?? category)
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                taskForm
            }
        } else {
            NavigationView {
                taskForm
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var taskForm: some View {
        Form {
            titleSection
            notesSection
            prioritySection
            dueDateSection
            recurrenceSection
            categorySection
        }
        .navigationTitle(isEditing ? "nav.edit_task".localized : "nav.new_task".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.cancel".localized) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("action.save".localized) {
                    saveTask()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.dismissKeyboard()
                }
        )
    }
    
    private var titleSection: some View {
        Section("task.title_section".localized) {
            TextField("task.title_placeholder".localized, text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var notesSection: some View {
        Section("task.notes_section".localized) {
            if #available(iOS 16.0, *) {
                TextField("task.notes_placeholder".localized, text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField("task.notes_placeholder".localized, text: $notes)
                    .lineLimit(6)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    private var prioritySection: some View {
        Section("task.priority".localized) {
            Picker("task.select_priority".localized, selection: $priority) {
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
        Section("task.due_date".localized) {
            Toggle("task.set_due_date".localized, isOn: $hasDueDate)
                .onChange(of: hasDueDate) { enabled in
                    if enabled && dueDate == nil {
                        dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                    } else if !enabled {
                        dueDate = nil
                    }
                }
            
            if hasDueDate {
                CustomDatePickerField(date: $dueDate)
            }
        }
    }
    
    private var recurrenceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    Text("task.repeat".localized)
                        .font(.headline)
                    
                    Spacer()
                    
                    if recurrenceType != .none {
                        Image(systemName: recurrenceType.systemImage)
                            .foregroundColor(recurrenceType.color)
                            .font(.caption)
                    }
                }
                
                Picker("recurrence.title".localized, selection: $recurrenceType) {
                    ForEach(RecurrenceType.allCases) { type in
                        HStack {
                            Image(systemName: type.systemImage)
                                .foregroundColor(type.color)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.title)
                                    .font(.body)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                if recurrenceType != .none && !hasDueDate {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("task.recurring_requires_date".localized)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
                
                if recurrenceType != .none && hasDueDate, let dueDate = dueDate {
                    let nextDate = recurrenceType.safeNextDueDate(from: dueDate)
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("task.next_occurrence".localized(with: DateFormatter.taskDate.string(from: nextDate)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        } header: {
            Text("recurrence.title".localized)
        } footer: {
            if recurrenceType != .none {
                Text("task.recurring_description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var categorySection: some View {
        Section("task.category".localized) {
            if categories.isEmpty {
                Button("category.create_first".localized) {
                    createDefaultCategory()
                }
                .foregroundColor(.blue)
            } else {
                Picker("task.category".localized, selection: $selectedCategory) {
                    Text("option.none".localized).tag(nil as TaskCategory?)
                    
                    ForEach(categories, id: \.self) { category in
                        HStack {
                            Circle()
                                .fill(Color(hex: category.colorHex ?? "#007AFF"))
                                .frame(width: 12, height: 12)
                            Text(category.name ?? "category.unnamed".localized)
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
            // Validate recurrence requirements
            if recurrenceType != .none && !hasDueDate {
                // For now, we'll silently set recurrence to none if no due date
                // In a production app, you might want to show an alert
                print("Warning: Recurring task requires a due date. Setting recurrence to none.")
            }
            
            let taskToSave: Task
            
            if let existingTask = task {
                // Update existing task
                existingTask.title = title
                existingTask.notes = notes.isEmpty ? nil : notes
                existingTask.priority = Int16(priority.rawValue)
                existingTask.dueDate = hasDueDate ? dueDate : nil
                existingTask.category = selectedCategory
                existingTask.recurrenceTypeEnum = hasDueDate ? recurrenceType : .none
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
                newTask.recurrenceTypeEnum = hasDueDate ? recurrenceType : .none
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
                
                // Update badge count after task creation or editing
                NotificationManager.shared.handleTaskStateChange()
                
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
            category.name = "personal.category_name".localized
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