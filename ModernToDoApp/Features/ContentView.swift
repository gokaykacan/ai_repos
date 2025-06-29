import SwiftUI
import CoreData
import UserNotifications

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Tasks")
                }
                .tag(0)
                .transition(.slide)
            
            CategoriesView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("Categories")
                }
                .tag(1)
                .transition(.slide)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
                .transition(.slide)

            ProductivityChartView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Insights")
                }
                .tag(3)
                .transition(.slide)
            
        }
        .accentColor(.blue)
        .animation(.default, value: selectedTab)
    }
}

struct TaskSection: Identifiable {
    let id = UUID()
    let title: String
    let tasks: [Task]
}

enum TaskSheetType: Identifiable {
    case detail(Task)
    case edit(Task)
    case postpone(Task, Date)
    
    var id: String {
        switch self {
        case .detail(let task): return "detail-\(task.objectID)"
        case .edit(let task): return "edit-\(task.objectID)"
        case .postpone(let task, _): return "postpone-\(task.objectID)"
        }
    }
}

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedTab: Int
    @State private var activeSheet: TaskSheetType?
    @State private var searchText = ""
    @State private var selectedCategory: TaskCategory?
    @State private var showingAddTask = false
    @State private var isInSelectionMode = false
    @State private var selectedTasks: Set<Task> = []
    @State private var showingDeleteTaskAlert = false
    @State private var taskToDelete: Task?
    @State private var showingDeleteMultipleTasksAlert = false
    @State private var tasksToDelete: [Task] = []
    @State private var sectionForDeletion: TaskSection?
    @State private var offsetsForDeletion: IndexSet?
    @AppStorage("showCompletedTasks") private var showCompletedTasks = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Task.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)
        ])
    private var tasks: FetchedResults<Task>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskCategory.name, ascending: true)])
    private var categories: FetchedResults<TaskCategory>
    
    private var filteredTasks: [Task] {
        let taskArray = Array(tasks)
        
        // Filter by completed status first
        let visibleTasks = showCompletedTasks ? taskArray : taskArray.filter { !$0.isCompleted }
        
        // Filter by category if selected
        let categoryFilteredTasks = if let selectedCategory = selectedCategory {
            visibleTasks.filter { $0.category == selectedCategory }
        } else {
            visibleTasks
        }
        
        // Then filter by search text if needed
        if searchText.isEmpty {
            return categoryFilteredTasks
        } else {
            return categoryFilteredTasks.filter { task in
                task.title?.localizedCaseInsensitiveContains(searchText) == true ||
                task.notes?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    private var groupedTasks: [TaskSection] {
        let calendar = Calendar.current
        let now = Date()

        let overdueTasks = filteredTasks.filter { $0.isOverdue && !$0.isCompleted }
        let todayTasks = filteredTasks.filter { $0.isDueToday && !$0.isCompleted && !$0.isOverdue }
        let tomorrowTasks = filteredTasks.filter { $0.isDueTomorrow && !$0.isCompleted }
        let upcomingTasks = filteredTasks.filter {
            guard let dueDate = $0.dueDate else { return false }
            return !calendar.isDateInToday(dueDate) && !calendar.isDateInTomorrow(dueDate) && dueDate > now && !$0.isCompleted
        }
        let noDueDateTasks = filteredTasks.filter { $0.dueDate == nil && !$0.isCompleted }
        let completedTasks = filteredTasks.filter { $0.isCompleted }

        var sections: [TaskSection] = []

        if !overdueTasks.isEmpty {
            sections.append(TaskSection(title: "Overdue", tasks: overdueTasks.sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }))
        }
        if !todayTasks.isEmpty {
            sections.append(TaskSection(title: "Today", tasks: todayTasks.sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }))
        }
        if !tomorrowTasks.isEmpty {
            sections.append(TaskSection(title: "Tomorrow", tasks: tomorrowTasks.sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }))
        }
        if !upcomingTasks.isEmpty {
            sections.append(TaskSection(title: "Upcoming", tasks: upcomingTasks.sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }))
        }
        if !noDueDateTasks.isEmpty {
            sections.append(TaskSection(title: "No Due Date", tasks: noDueDateTasks.sorted {
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                } else {
                    return $0.createdAt ?? Date() < $1.createdAt ?? Date()
                }
            }))
        }
        if !completedTasks.isEmpty && showCompletedTasks {
            sections.append(TaskSection(title: "Completed", tasks: completedTasks.sorted { $0.updatedAt ?? Date() > $1.updatedAt ?? Date() }))
        }

        return sections
    }
    
    // MARK: - Selection Mode Helper Functions
    private func enterSelectionMode(with task: Task) {
        isInSelectionMode = true
        selectedTasks.insert(task)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func exitSelectionMode() {
        isInSelectionMode = false
        selectedTasks.removeAll()
    }
    
    private func toggleTaskSelection(_ task: Task) {
        if selectedTasks.contains(task) {
            selectedTasks.remove(task)
        } else {
            selectedTasks.insert(task)
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func deleteSelectedTasks() {
        withAnimation {
            for task in selectedTasks {
                // Cancel notification before deleting
                if notificationsEnabled {
                    NotificationManager.shared.cancelNotification(for: task)
                }
                viewContext.delete(task)
            }
            
            do {
                try viewContext.save()
                exitSelectionMode()
            } catch {
                print("Error deleting selected tasks: \(error)")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Section
                VStack(spacing: 0) {
                    UltraMinimalistSearchBar(
                        text: $searchText,
                        placeholder: "Search tasks..."
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                
                // Filter Section (separate from search)
                if !categories.isEmpty {
                    HStack {
                        Text("Filter")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Spacer()
                        
                        Menu {
                            Button(action: {
                                selectedCategory = nil
                            }) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                        .foregroundColor(.blue)
                                    Text("All Categories")
                                    Spacer()
                                    if selectedCategory == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            if !categories.isEmpty {
                                Divider()
                            }
                            
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: category.colorHex ?? "#007AFF"))
                                            .frame(width: 12, height: 12)
                                        Image(systemName: category.icon ?? "folder")
                                            .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                        Text(category.name ?? "Unnamed")
                                        Spacer()
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if let selectedCategory = selectedCategory {
                                    Circle()
                                        .fill(Color(hex: selectedCategory.colorHex ?? "#007AFF"))
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(selectedCategory?.name ?? "All Categories")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                .regularMaterial,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .menuOrder(.fixed)
                        .menuActionDismissBehavior(.enabled)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                
                Divider()
                
                List {
                    if groupedTasks.isEmpty && searchText.isEmpty {
                        Text("No tasks found. Tap '+' to add a new task!")
                            .foregroundColor(.secondary)
                            .padding()
                    } else if groupedTasks.isEmpty && !searchText.isEmpty {
                        Text("No tasks found matching your search.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(groupedTasks) { section in
                            Section {
                                ForEach(section.tasks, id: \.self) { task in
                                    TaskCardView(
                                        task: task,
                                        isInSelectionMode: isInSelectionMode,
                                        isSelected: selectedTasks.contains(task),
                                        onTap: {
                                            if isInSelectionMode {
                                                toggleTaskSelection(task)
                                            } else {
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                impactFeedback.impactOccurred()
                                                activeSheet = .detail(task)
                                            }
                                        },
                                        onLongPress: {
                                            if !isInSelectionMode {
                                                enterSelectionMode(with: task)
                                            }
                                        },
                                        onEdit: {
                                            activeSheet = .edit(task)
                                        },
                                        onTaskUpdated: {
                                            // Trigger UI refresh by updating a state variable
                                            // This ensures SwiftUI re-evaluates the computed properties
                                        }
                                    )
                                    .if(!isInSelectionMode) { view in
                                        view
                                            .swipeActions(edge: .trailing) {
                                                Button("Delete", role: .destructive) {
                                                    taskToDelete = task
                                                    showingDeleteTaskAlert = true
                                                }
                                                
                                                Button("Edit") {
                                                    activeSheet = .edit(task)
                                                }
                                                .tint(.blue)
                                                
                                                Button("Postpone") {
                                                    let postponeDate = task.dueDate ?? Date()
                                                    activeSheet = .postpone(task, postponeDate)
                                                }
                                                .tint(.orange)
                                            }
                                            .swipeActions(edge: .leading) {
                                                Button(task.isCompleted ? "Incomplete" : "Complete") {
                                                    withAnimation {
                                                        let wasCompleted = task.isCompleted
                                                        
                                                        if !wasCompleted {
                                                            // Completing the task
                                                            task.handleTaskCompletion(in: viewContext)
                                                            
                                                            // Cancel notification since task is completed
                                                            if notificationsEnabled {
                                                                NotificationManager.shared.cancelNotification(for: task)
                                                            }
                                                        } else {
                                                            // Marking task as incomplete
                                                            task.isCompleted = false
                                                            task.updatedAt = Date()
                                                            
                                                            // Reschedule notification if task has due date
                                                            if notificationsEnabled && task.dueDate != nil {
                                                                NotificationManager.shared.scheduleNotification(for: task)
                                                            }
                                                        }
                                                        
                                                        do {
                                                            try viewContext.save()
                                                        } catch {
                                                            print("Error toggling task completion: \(error)")
                                                            // Rollback the change
                                                            task.isCompleted = wasCompleted
                                                            try? viewContext.save()
                                                        }
                                                    }
                                                }
                                                .tint(task.isCompleted ? .orange : .green)
                                            }
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                                .onDelete { offsets in
                                    sectionForDeletion = section
                                    offsetsForDeletion = offsets
                                    tasksToDelete = offsets.map { section.tasks[$0] }
                                    showingDeleteMultipleTasksAlert = true
                                }
                            } header: {
                                Text(section.title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .textCase(nil)
                                    .padding(.leading, 16)
                                    .padding(.top, 8)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Left toolbar item - varies based on selection mode
                ToolbarItem(placement: .navigationBarLeading) {
                    if isInSelectionMode {
                        Button("Cancel") {
                            exitSelectionMode()
                        }
                    } else {
                        // Placeholder for existing filter button if any
                        EmptyView()
                    }
                }
                
                // Right toolbar item - varies based on selection mode
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isInSelectionMode {
                        if !selectedTasks.isEmpty {
                            Button("Delete Selected") {
                                deleteSelectedTasks()
                            }
                            .foregroundColor(.red)
                        } else {
                            EmptyView()
                        }
                    } else {
                        Button(action: { showingAddTask = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                TaskDetailView(category: selectedCategory)
            }
            .sheet(item: $activeSheet) { sheetType in
                switch sheetType {
                case .detail(let task):
                    SimpleTaskDetailView(task: task)
                case .edit(let task):
                    TaskDetailView(task: task)
                case .postpone(let task, let initialDate):
                    PostponeTaskView(task: task, initialDate: initialDate, viewContext: viewContext, notificationsEnabled: notificationsEnabled) {
                        activeSheet = nil
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                TaskDetailView(category: selectedCategory)
            }
            .alert("Delete Task", isPresented: $showingDeleteTaskAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Task", role: .destructive) {
                    if let task = taskToDelete {
                        deleteTask(task)
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(taskToDelete?.title ?? "this task")\"? This action cannot be undone.")
            }
            .alert("Delete Tasks", isPresented: $showingDeleteMultipleTasksAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Tasks", role: .destructive) {
                    if let section = sectionForDeletion, let offsets = offsetsForDeletion {
                        deleteItems(for: section, at: offsets)
                    }
                }
            } message: {
                let taskCount = tasksToDelete.count
                let taskText = taskCount == 1 ? "task" : "tasks"
                Text("Are you sure you want to delete \(taskCount) \(taskText)? This action cannot be undone.")
            }
        }
    }
    
    private func deleteTask(_ task: Task) {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Cancel notification before deleting
            if notificationsEnabled {
                NotificationManager.shared.cancelNotification(for: task)
            }
            
            viewContext.delete(task)
            
            do {
                try viewContext.save()
                print("Successfully deleted task: \(task.title ?? "Unknown")")
                
                // Success haptic feedback
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
            } catch {
                print("Error deleting task: \(error)")
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
            // Reset state
            taskToDelete = nil
        }
    }
    
    private func deleteItems(for section: TaskSection, at offsets: IndexSet) {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            let tasksToDelete = offsets.map { section.tasks[$0] }
            
            // Cancel notifications for all tasks being deleted
            if notificationsEnabled {
                for task in tasksToDelete {
                    NotificationManager.shared.cancelNotification(for: task)
                }
            }
            
            tasksToDelete.forEach(viewContext.delete)

            do {
                try viewContext.save()
                print("Successfully deleted \(tasksToDelete.count) tasks")
                
                // Success haptic feedback
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
            } catch {
                print("Error deleting tasks: \(error)")
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
            // Reset state
            sectionForDeletion = nil
            offsetsForDeletion = nil
            self.tasksToDelete = []
        }
    }
}

struct PostponeTaskView: View {
    let task: Task
    @State private var newPostponeDate: Date
    let viewContext: NSManagedObjectContext
    let notificationsEnabled: Bool
    let onDismiss: () -> Void
    
    init(task: Task, initialDate: Date, viewContext: NSManagedObjectContext, notificationsEnabled: Bool, onDismiss: @escaping () -> Void) {
        self.task = task
        self._newPostponeDate = State(initialValue: initialDate)
        self.viewContext = viewContext
        self.notificationsEnabled = notificationsEnabled
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                DatePicker(
                    "",
                    selection: $newPostponeDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                Spacer()
            }
            .navigationTitle("Postpone Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        withAnimation {
                            task.dueDate = newPostponeDate
                            task.updatedAt = Date()
                            task.postponeDate = Date()

                            do {
                                try viewContext.save()

                                if notificationsEnabled {
                                    NotificationManager.shared.cancelNotification(for: task)
                                    if task.dueDate != nil {
                                        NotificationManager.shared.scheduleNotification(for: task)
                                    }
                                }
                            } catch {
                                print("Error postponing task: \(error)")
                            }
                        }
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct TaskCardView: View {
    let task: Task
    let isInSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onEdit: (() -> Void)?
    let onTaskUpdated: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color {
        if isSelected {
            return .blue.opacity(0.1)
        }
        return colorScheme == .dark 
            ? Color(UIColor.systemGray6)
            : Color(UIColor.systemBackground)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Selection indicator in selection mode
                if isInSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                        .frame(width: 24, height: 24)
                } else {
                    // Completion status indicator in normal mode
                    Circle()
                        .fill(task.isCompleted ? Color.green : task.priorityEnum.color.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(task.priorityEnum.color, lineWidth: task.isCompleted ? 0 : 2)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title row with priority and recurrence indicators
                    HStack(spacing: 8) {
                        Text(task.title ?? "Untitled Task")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)
                        
                        Spacer()
                        
                        // Priority indicator
                        if !task.isCompleted {
                            PriorityIndicatorView(priority: task.priorityEnum)
                        }
                        
                        // Recurring task indicator
                        if task.hasRecurrence {
                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundColor(task.recurrenceTypeEnum.color)
                        }
                        
                        if !isInSelectionMode {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Metadata row (category, due date)
                    HStack(spacing: 12) {
                        // Category
                        if let category = task.category {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: category.colorHex ?? "#007AFF"))
                                    .frame(width: 6, height: 6)
                                Text(category.name ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Due date
                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(dueDate < Date() && !task.isCompleted ? .red : .secondary)
                                Text(DateFormatter.taskDate.string(from: dueDate))
                                    .font(.caption)
                                    .foregroundColor(dueDate < Date() && !task.isCompleted ? .red : .secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Notes preview
                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Progress indicator for subtasks
                    if task.subtaskArray.count > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: task.completionPercentage)
                                .progressViewStyle(.linear)
                                .tint(.accentColor)
                            Text("\(Int(task.completionPercentage * 100))% completed • \(task.completedSubtasks.count)/\(task.subtaskArray.count) subtasks")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: colorScheme == .dark ? .clear : .black.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    colorScheme == .dark ? Color.gray.opacity(0.2) : Color.clear,
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
    }
}

enum CategorySortOption: String, CaseIterable, Identifiable {
    case alphabetical = "alphabetical"
    case creationDate = "creationDate"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .alphabetical:
            return "A → Z"
        case .creationDate:
            return "Newest First"
        }
    }
    
    var systemImage: String {
        switch self {
        case .alphabetical:
            return "textformat.abc"
        case .creationDate:
            return "calendar"
        }
    }
}

struct CategoriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var editingCategory: TaskCategory?
    @State private var selectedCategoryForDetail: TaskCategory?
    @State private var showingAddCategory = false
    @State private var searchText = ""
    @State private var sortOption: CategorySortOption = .alphabetical
    @State private var showingDeleteTasksAlert = false
    @State private var categoryToDeleteTasksFrom: TaskCategory?
    @State private var showingDeleteCategoryAlert = false
    @State private var categoryToDelete: TaskCategory?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskCategory.sortOrder, ascending: true)])
    private var categories: FetchedResults<TaskCategory>
    
    private var filteredAndSortedCategories: [TaskCategory] {
        let categoryArray = Array(categories)
        
        // Filter by search text first
        let filteredCategories = if searchText.isEmpty {
            categoryArray
        } else {
            categoryArray.filter { category in
                category.name?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Then sort based on selected option
        return filteredCategories.sorted { first, second in
            switch sortOption {
            case .alphabetical:
                let firstName = first.name?.lowercased() ?? ""
                let secondName = second.name?.lowercased() ?? ""
                return firstName < secondName
            case .creationDate:
                let firstDate = first.createdAt ?? Date.distantPast
                let secondDate = second.createdAt ?? Date.distantPast
                return firstDate > secondDate // Newest first
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Section
                VStack(spacing: 0) {
                    UltraMinimalistSearchBar(
                        text: $searchText,
                        placeholder: "Search categories..."
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                
                // Sort Section (separate from search)
                HStack {
                    Text("Sort")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(CategorySortOption.allCases) { option in
                            Button(action: {
                                sortOption = option
                            }) {
                                HStack {
                                    Image(systemName: option.systemImage)
                                        .foregroundColor(.blue)
                                    Text(option.title)
                                    Spacer()
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(sortOption.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuOrder(.fixed)
                    .menuActionDismissBehavior(.enabled)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Categories list
                List {
                    ForEach(filteredAndSortedCategories, id: \.self) { category in
                        CategoryCardView(category: category, onTap: {
                            // Add haptic feedback for tap
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            selectedCategoryForDetail = category
                        }, onEdit: {
                            editingCategory = category
                        })
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button("Edit") {
                                editingCategory = category
                            }
                            .tint(.blue)
                            
                            Button("Delete All Tasks") {
                                categoryToDeleteTasksFrom = category
                                showingDeleteTasksAlert = true
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .leading) {
                            Button("Delete Category", role: .destructive) {
                                categoryToDelete = category
                                showingDeleteCategoryAlert = true
                            }
                        }
                    }
                    .onDelete(perform: deleteCategories)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCategory = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                CategoryDetailView()
            }
            .sheet(item: $editingCategory) { category in
                CategoryDetailView(category: category)
            }
            .sheet(item: $selectedCategoryForDetail) { category in
                SimpleCategoryDetailView(category: category)
            }
            .alert("Delete All Tasks", isPresented: $showingDeleteTasksAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All Tasks", role: .destructive) {
                    if let category = categoryToDeleteTasksFrom {
                        deleteAllTasksFromCategory(category)
                    }
                }
            } message: {
                Text("Are you sure you want to delete all tasks from \"\(categoryToDeleteTasksFrom?.name ?? "this category")\"? This action cannot be undone.")
            }
            .alert("Delete Category", isPresented: $showingDeleteCategoryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Category", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
            } message: {
                let taskCount = categoryToDelete?.tasks?.count ?? 0
                let taskText = taskCount == 1 ? "task" : "tasks"
                Text("Are you sure you want to delete \"\(categoryToDelete?.name ?? "this category")\" and all its \(taskCount) \(taskText)? This action cannot be undone.")
            }
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredAndSortedCategories[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting category: \(error)")
            }
        }
    }
    
    private func deleteCategory(_ category: TaskCategory) {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Cancel notifications for all tasks in this category before deleting
            if let tasks = category.tasks as? Set<Task> {
                for task in tasks {
                    NotificationManager.shared.cancelNotification(for: task)
                }
            }
            
            viewContext.delete(category)
            
            do {
                try viewContext.save()
                print("Successfully deleted category: \(category.name ?? "Unknown")")
                
                // Success haptic feedback
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
            } catch {
                print("Error deleting category: \(error)")
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
            // Reset state
            categoryToDelete = nil
        }
    }
    
    private func deleteAllTasksFromCategory(_ category: TaskCategory) {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Get all tasks from this category
            guard let tasks = category.tasks as? Set<Task> else { 
                print("No tasks found in category")
                return 
            }
            
            // Cancel notifications for all tasks being deleted
            for task in tasks {
                NotificationManager.shared.cancelNotification(for: task)
            }
            
            // Delete all tasks
            for task in tasks {
                viewContext.delete(task)
            }
            
            do {
                try viewContext.save()
                print("Successfully deleted \(tasks.count) tasks from category: \(category.name ?? "Unknown")")
                
                // Additional haptic feedback for success
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
            } catch {
                print("Error deleting tasks from category: \(error)")
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
            // Reset state
            categoryToDeleteTasksFrom = nil
        }
    }
}

struct CategoryCardView: View {
    let category: TaskCategory
    let onTap: () -> Void
    let onEdit: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var taskCount: Int {
        category.tasks?.count ?? 0
    }
    
    var completedTaskCount: Int {
        let tasks = category.tasks as? Set<Task> ?? []
        return tasks.filter { $0.isCompleted }.count
    }
    
    var pendingTaskCount: Int {
        taskCount - completedTaskCount
    }
    
    private var cardBackground: Color {
        colorScheme == .dark 
            ? Color(UIColor.systemGray6)
            : Color(UIColor.systemBackground)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Category Icon with colored background
                    ZStack {
                        Circle()
                            .fill(Color(hex: category.colorHex ?? "#007AFF").opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .fill(Color(hex: category.colorHex ?? "#007AFF"))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: category.icon ?? "folder")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(category.name ?? "Unnamed Category")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Task count with breakdown
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(taskCount) total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if pendingTaskCount > 0 {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                    Text("\(pendingTaskCount) pending")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if completedTaskCount > 0 {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    Text("\(completedTaskCount) done")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Progress bar if there are tasks
                        if taskCount > 0 {
                            ProgressView(value: Double(completedTaskCount) / Double(taskCount))
                                .progressViewStyle(.linear)
                                .tint(Color(hex: category.colorHex ?? "#007AFF"))
                                .scaleEffect(y: 0.8)
                        }
                    }
                }
                .padding(16)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                radius: 8,
                x: 0,
                y: 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        colorScheme == .dark ? Color.gray.opacity(0.2) : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showCompletedTasks") private var showCompletedTasks = true
    @State private var showingClearDataAlert = false
    @State private var showingClearTasksAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { enabled in
                            if enabled {
                                NotificationManager.shared.requestPermission()
                                NotificationManager.shared.checkNotificationSettings()
                            } else {
                                // Cancel all pending notifications when disabled
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                }
                
                Section("Tasks") {
                    Toggle("Show Completed Tasks", isOn: $showCompletedTasks)
                }
                
                
                Section("Data") {
                    Button("Clear All Tasks") {
                        showingClearTasksAlert = true
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear All Data") {
                        showingClearDataAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("Are you sure you want to delete all tasks and categories? This action cannot be undone.")
            }
            .alert("Clear All Tasks", isPresented: $showingClearTasksAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Tasks", role: .destructive) {
                    clearAllTasks()
                }
            } message: {
                Text("Are you sure you want to delete all tasks? Categories will remain.")
            }
        }
    }
    
    private func clearAllData() {
        withAnimation {
            do {
                // Cancel all pending notifications first
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                
                // Delete all tasks
                let taskFetch: NSFetchRequest<Task> = Task.fetchRequest()
                let tasks = try viewContext.fetch(taskFetch)
                for task in tasks {
                    viewContext.delete(task)
                }
                
                // Delete all categories
                let categoryFetch: NSFetchRequest<TaskCategory> = TaskCategory.fetchRequest()
                let categories = try viewContext.fetch(categoryFetch)
                for category in categories {
                    viewContext.delete(category)
                }
                
                // Save changes
                try viewContext.save()
                
                print("Successfully cleared all data")
            } catch {
                print("Error clearing data: \(error)")
            }
        }
    }
    
    private func clearAllTasks() {
        withAnimation {
            do {
                // Cancel all pending notifications first
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                
                // Delete all tasks
                let taskFetch: NSFetchRequest<Task> = Task.fetchRequest()
                let tasks = try viewContext.fetch(taskFetch)
                for task in tasks {
                    viewContext.delete(task)
                }
                
                // Save changes
                try viewContext.save()
                
                print("Successfully cleared all tasks")
            } catch {
                print("Error clearing tasks: \(error)")
            }
        }
    }
}

// Helper for date formatting
extension DateFormatter {
    static let taskDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

// Core Data objects with "class" code generation already conform to Identifiable

// MARK: - Simple Detail Views
struct SimpleTaskDetailView: View {
    let task: Task
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task Title
                    Text(task.title ?? "Untitled Task")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .accessibilityLabel("Task title: \(task.title ?? "Untitled Task")")
                        .accessibilityAddTraits(.isHeader)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Priority
                        DetailRow(title: "Priority", 
                                value: "\(task.priorityEnum.title) Priority",
                                icon: task.priorityEnum.systemImage,
                                color: task.priorityEnum.color)
                        
                        // Category
                        if let category = task.category {
                            DetailRow(title: "Category",
                                    value: category.name ?? "Unnamed",
                                    icon: category.icon ?? "folder",
                                    color: Color(hex: category.colorHex ?? "#007AFF"))
                        }
                        
                        // Due Date
                        if let dueDate = task.dueDate {
                            DetailRow(title: "Due Date",
                                    value: DateFormatter.taskDate.string(from: dueDate),
                                    icon: "calendar",
                                    color: dueDate < Date() && !task.isCompleted ? .red : .blue)
                        }
                        
                        // Status
                        DetailRow(title: "Status",
                                value: task.isCompleted ? "Completed" : "Pending",
                                icon: task.isCompleted ? "checkmark.circle.fill" : "circle",
                                color: task.isCompleted ? .green : .orange)
                        
                        // Creation Date
                        if let createdAt = task.createdAt {
                            DetailRow(title: "Created",
                                    value: DateFormatter.taskDate.string(from: createdAt),
                                    icon: "plus.circle",
                                    color: .secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Description
                    if let notes = task.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(.blue)
                                Text("Description")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                            
                            Text(notes)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Subtasks
                    if !task.subtaskArray.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "list.bullet.indent")
                                    .foregroundColor(.orange)
                                Text("Subtasks (\(task.subtaskArray.count))")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(task.completedSubtasks.count)/\(task.subtaskArray.count) completed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(task.subtaskArray, id: \.self) { subtask in
                                HStack {
                                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(subtask.isCompleted ? .green : .secondary)
                                    Text(subtask.title ?? "Untitled Subtask")
                                        .strikethrough(subtask.isCompleted)
                                    Spacer()
                                    PriorityIndicatorView(priority: subtask.priorityEnum)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct SimpleCategoryDetailView: View {
    let category: TaskCategory
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: TaskFilter = .all
    
    private var categoryTasks: [Task] {
        let tasksSet = category.tasks as? Set<Task> ?? []
        return Array(tasksSet).sorted { $0.createdAt ?? Date() > $1.createdAt ?? Date() }
    }
    
    private var filteredTasks: [Task] {
        switch selectedFilter {
        case .all:
            return categoryTasks
        case .completed:
            return categoryTasks.filter { $0.isCompleted }
        case .pending:
            return categoryTasks.filter { !$0.isCompleted }
        }
    }
    
    enum TaskFilter {
        case all, completed, pending
        
        var title: String {
            switch self {
            case .all: return "All Tasks"
            case .completed: return "Completed Tasks"
            case .pending: return "Pending Tasks"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category Header
                    HStack {
                        Circle()
                            .fill(Color(hex: category.colorHex ?? "#007AFF"))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: category.icon ?? "folder")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(category.name ?? "Unnamed Category")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .accessibilityLabel("Category name: \(category.name ?? "Unnamed Category")")
                                .accessibilityAddTraits(.isHeader)
                            
                            if let createdAt = category.createdAt {
                                Text("Created \(DateFormatter.taskDate.string(from: createdAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Statistics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Total", 
                            value: "\(categoryTasks.count)", 
                            color: .blue, 
                            icon: "list.bullet",
                            isSelected: selectedFilter == .all,
                            onTap: { selectedFilter = .all }
                        )
                        StatCard(
                            title: "Completed", 
                            value: "\(categoryTasks.filter { $0.isCompleted }.count)", 
                            color: .green, 
                            icon: "checkmark.circle.fill",
                            isSelected: selectedFilter == .completed,
                            onTap: { selectedFilter = .completed }
                        )
                        StatCard(
                            title: "Pending", 
                            value: "\(categoryTasks.filter { !$0.isCompleted }.count)", 
                            color: .orange, 
                            icon: "circle",
                            isSelected: selectedFilter == .pending,
                            onTap: { selectedFilter = .pending }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Filtered Tasks
                    if !filteredTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(selectedFilter.title)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(filteredTasks.count) task\(filteredTasks.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(filteredTasks, id: \.self) { task in
                                HStack {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(task.isCompleted ? .green : .secondary)
                                    
                                    VStack(alignment: .leading) {
                                        Text(task.title ?? "Untitled Task")
                                            .font(.body)
                                            .strikethrough(task.isCompleted)
                                        
                                        if let dueDate = task.dueDate {
                                            Text(DateFormatter.taskDate.string(from: dueDate))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    PriorityIndicatorView(priority: task.priorityEnum)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                
                                VStack(spacing: 16) {
                                    Image(systemName: selectedFilter == .completed ? "checkmark.circle" : selectedFilter == .pending ? "circle" : "tray")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    
                                    Text(selectedFilter == .all ? "No Tasks Yet" : selectedFilter == .completed ? "No Completed Tasks" : "No Pending Tasks")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    Text(selectedFilter == .all ? "Tasks added to this category will appear here" : selectedFilter == .completed ? "Complete some tasks to see them here" : "All tasks in this category are completed!")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                Spacer()
                            }
                            .frame(width: geometry.size.width, height: max(geometry.size.height, 400))
                        }
                        .frame(minHeight: 400)
                    }
                }
            }
            .navigationTitle("Category Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .accessibilityHidden(true)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .accessibilityHidden(true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityValue(value)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                    .accessibilityHidden(true)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? color : Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint("Tap to filter tasks")
        .accessibilityValue(value)
        .accessibilityAddTraits(.isSummaryElement)
    }
}

// MARK: - View Extensions
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, CoreDataStack.shared.container.viewContext)
    }
}

// MARK: - Enhanced UI Components

// MARK: - Ultra Minimalist Search Bar
struct UltraMinimalistSearchBar: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Search Icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            // Text Field
            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.primary)
                .focused($isFocused)
                .submitLabel(.search)
            
            // Clear Button
            if !text.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        )
    }
}

// MARK: - Enhanced Menu
struct EnhancedMenu<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content
    @State private var isPressed = false
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    private var buttonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.8),
                Color.purple.opacity(0.6)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .rotationEffect(.degrees(isPressed ? 180 : 0))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    buttonGradient
                    
                    // Shine effect
                    if isPressed {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white.opacity(0.3),
                                .clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: .blue.opacity(0.4),
                radius: isPressed ? 12 : 6,
                x: 0,
                y: isPressed ? 6 : 3
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .pressEvents(
            onPress: {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
            },
            onRelease: {
                withAnimation(.easeOut(duration: 0.2)) {
                    isPressed = false
                }
            }
        )
    }
}

// MARK: - Enhanced Menu Item
struct EnhancedMenuItem: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .medium, design: .rounded))
        }
        .foregroundStyle(
            LinearGradient(
                gradient: Gradient(colors: [color, color.opacity(0.7)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

// MARK: - Filter Pill Button
struct FilterPillButton: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    private var backgroundGradient: LinearGradient {
        if isSelected {
            return LinearGradient(
                gradient: Gradient(colors: [color, color.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.2),
                    Color.gray.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    backgroundGradient
                    
                    // Pressed state overlay
                    if isPressed {
                        Color.white.opacity(0.2)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? color.opacity(0.5) : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? color.opacity(0.4) : .black.opacity(0.1),
                radius: isSelected ? 6 : 2,
                x: 0,
                y: isSelected ? 3 : 1
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .pressEvents(
            onPress: {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
            },
            onRelease: {
                withAnimation(.easeOut(duration: 0.2)) {
                    isPressed = false
                }
            }
        )
    }
}

// MARK: - Press Event Modifier
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

