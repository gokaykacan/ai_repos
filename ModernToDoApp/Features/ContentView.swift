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
                // Category filter section
                if !categories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Category")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        Picker("Category", selection: $selectedCategory) {
                            Text("All Categories").tag(nil as TaskCategory?)
                            
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
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                }
                
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
                            Section(header: Text(section.title)) {
                                ForEach(section.tasks, id: \.self) { task in
                                    TaskRowView(
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
                                                    withAnimation {
                                                        // Cancel notification before deleting
                                                        if notificationsEnabled {
                                                            NotificationManager.shared.cancelNotification(for: task)
                                                        }
                                                        
                                                        viewContext.delete(task)
                                                        
                                                        do {
                                                            try viewContext.save()
                                                        } catch {
                                                            print("Error deleting task: \(error)")
                                                        }
                                                    }
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
                                }
                                .onDelete { offsets in
                                    deleteItems(for: section, at: offsets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks...")
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
        }
    }
    
    private func deleteItems(for section: TaskSection, at offsets: IndexSet) {
        withAnimation {
            offsets.map { section.tasks[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                print("Error deleting task: \(error)")
            }
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

struct TaskRowView: View {
    let task: Task
    let isInSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onEdit: (() -> Void)?
    let onTaskUpdated: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator in selection mode
            if isInSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
                    .frame(width: 24, height: 24)
            } else {
                // Completion status indicator in normal mode
                Rectangle()
                    .fill(task.isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 40)
                    .cornerRadius(2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title row with priority icon on the left
                HStack(spacing: 8) {
                    // Priority indicator on the left
                    PriorityIndicatorView(priority: task.priorityEnum)
                    
                    // Recurring task indicator
                    if task.hasRecurrence {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(task.recurrenceTypeEnum.color)
                            .frame(width: 12, height: 12)
                    }
                    
                    Text(task.title ?? "Untitled Task")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                    
                    Spacer()
                }
                
                // Category and due date info
                VStack(alignment: .leading, spacing: 4) {
                    // Category
                    if let category = task.category {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: category.colorHex ?? "#007AFF"))
                                .frame(width: 8, height: 8)
                            Text(category.name ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Due date
                    if let dueDate = task.dueDate {
                        Text(DateFormatter.taskDate.string(from: dueDate))
                            .font(.caption)
                            .foregroundColor(dueDate < Date() && !task.isCompleted ? .red : .secondary)
                    }
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
                    ProgressView(value: task.completionPercentage)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .padding(.top, 2)
                    Text("\(Int(task.completionPercentage * 100))% Completed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Detail view arrow on the right (only in normal mode)
            if !isInSelectionMode {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .background(
            isSelected ? Color.blue.opacity(0.1) : Color.clear
        )
        .cornerRadius(8)
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
                // Sort filter section - appears below search bar
                HStack {
                    Menu {
                        ForEach(CategorySortOption.allCases) { option in
                            Button(action: {
                                sortOption = option
                            }) {
                                Label(option.title, systemImage: option.systemImage)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Sort: \(sortOption.title)")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGroupedBackground))
                
                // Categories list
                List {
                    ForEach(filteredAndSortedCategories, id: \.self) { category in
                        CategoryRowView(category: category, onTap: {
                            // Add haptic feedback for tap
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            selectedCategoryForDetail = category
                        }, onEdit: {
                            editingCategory = category
                        })
                        .swipeActions(edge: .trailing) {
                            Button("Edit") {
                                editingCategory = category
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            Button("Delete", role: .destructive) {
                                deleteCategory(category)
                            }
                        }
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
            .navigationTitle("Categories")
            .searchable(text: $searchText, prompt: "Search categories...")
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
        withAnimation {
            viewContext.delete(category)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting category: \(error)")
            }
        }
    }
}

struct CategoryRowView: View {
    let category: TaskCategory
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var taskCount: Int {
        category.tasks?.count ?? 0
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: category.colorHex ?? "#007AFF"))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: category.icon ?? "folder")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name ?? "Unnamed Category")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(taskCount) tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
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