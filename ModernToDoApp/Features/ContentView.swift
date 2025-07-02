import SwiftUI
import CoreData
import UserNotifications
import UIKit
import Foundation

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("tab.tasks".localized)
                }
                .tag(0)
                .transition(.slide)
            
            CategoriesView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("tab.categories".localized)
                }
                .tag(1)
                .transition(.slide)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("tab.settings".localized)
                }
                .tag(2)
                .transition(.slide)

            ProductivityChartView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("tab.insights".localized)
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
    @State private var showingDeleteTaskAlert = false
    @State private var taskToDelete: Task?
    @State private var sectionForDeletion: TaskSection?
    @State private var offsetsForDeletion: IndexSet?
    @State private var refreshTrigger = Date()
    @State private var overdueTimer: Timer?
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
        let now = refreshTrigger // Use refreshTrigger to force re-evaluation

        // Use current date for real-time evaluation instead of computed properties
        let overdueTasks = filteredTasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < now
        }
        let todayTasks = filteredTasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            let isToday = calendar.isDateInToday(dueDate)
            let isNotOverdue = dueDate >= now
            return isToday && isNotOverdue
        }
        let tomorrowTasks = filteredTasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return calendar.isDateInTomorrow(dueDate)
        }
        let upcomingTasks = filteredTasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return !calendar.isDateInToday(dueDate) && !calendar.isDateInTomorrow(dueDate) && dueDate > now
        }
        let noDueDateTasks = filteredTasks.filter { $0.dueDate == nil && !$0.isCompleted }
        let completedTasks = filteredTasks.filter { $0.isCompleted }

        var sections: [TaskSection] = []

        if !overdueTasks.isEmpty {
            sections.append(TaskSection(title: "section.overdue".localized, tasks: overdueTasks.sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }))
        }
        if !todayTasks.isEmpty {
            sections.append(TaskSection(title: "section.today".localized, tasks: todayTasks.sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }))
        }
        if !tomorrowTasks.isEmpty {
            sections.append(TaskSection(title: "section.tomorrow".localized, tasks: tomorrowTasks.sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }))
        }
        if !upcomingTasks.isEmpty {
            sections.append(TaskSection(title: "section.upcoming".localized, tasks: upcomingTasks.sorted { $0.dueDate ?? Date() < $1.dueDate ?? Date() }))
        }
        if !noDueDateTasks.isEmpty {
            sections.append(TaskSection(title: "section.no_due_date".localized, tasks: noDueDateTasks.sorted {
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                } else {
                    return $0.createdAt ?? Date() < $1.createdAt ?? Date()
                }
            }))
        }
        if !completedTasks.isEmpty && showCompletedTasks {
            sections.append(TaskSection(title: "section.completed".localized, tasks: completedTasks.sorted { $0.updatedAt ?? Date() > $1.updatedAt ?? Date() }))
        }

        return sections
    }
    
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    taskListContent
                }
            } else {
                NavigationView {
                    taskListContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
    
    private var taskListContent: some View {
        VStack(spacing: 0) {
            // Search Section
            VStack(spacing: 0) {
                UltraMinimalistSearchBar(
                    text: $searchText,
                    placeholder: "task.search_placeholder".localized
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
                
                // Filter Section (separate from search)
                if !categories.isEmpty {
                    HStack {
                        Text("task.filter".localized)
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
                                    Text("task.all_categories".localized)
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
                                        Text(category.name ?? "category.unnamed".localized)
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
                                
                                Text(selectedCategory?.name ?? "task.all_categories".localized)
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
                        Text("task.no_tasks".localized)
                            .foregroundColor(.secondary)
                            .padding()
                    } else if groupedTasks.isEmpty && !searchText.isEmpty {
                        Text("task.no_search_results".localized)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(groupedTasks) { section in
                            Section {
                                ForEach(section.tasks, id: \.self) { task in
                                    TaskCardView(
                                        task: task,
                                        onTap: {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                            activeSheet = .detail(task)
                                        },
                                        onEdit: {
                                            activeSheet = .edit(task)
                                        },
                                        onTaskUpdated: {
                                            // Trigger UI refresh by updating a state variable
                                            // This ensures SwiftUI re-evaluates the computed properties
                                        }
                                    )
                                    .swipeActions(edge: .trailing) {
                                                Button("action.delete".localized, role: .destructive) {
                                                    taskToDelete = task
                                                    showingDeleteTaskAlert = true
                                                }
                                                
                                                Button("action.edit".localized) {
                                                    activeSheet = .edit(task)
                                                }
                                                .tint(.blue)
                                                
                                                Button("action.postpone".localized) {
                                                    let postponeDate = task.dueDate ?? Date()
                                                    activeSheet = .postpone(task, postponeDate)
                                                }
                                                .tint(.orange)
                                            }
                                            .swipeActions(edge: .leading) {
                                                Button(task.isCompleted ? "action.incomplete".localized : "action.complete".localized) {
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
                                                            
                                                            // Update badge count immediately after task completion change
                                                            NotificationManager.shared.handleTaskCompletion()
                                                        } catch {
                                                            print("Error toggling task completion: \(error)")
                                                            // Rollback the change
                                                            task.isCompleted = wasCompleted
                                                            try? viewContext.save()
                                                            
                                                            // Update badge even after rollback to ensure consistency
                                                            NotificationManager.shared.handleTaskCompletion()
                                                        }
                                                    }
                                                }
                                                .tint(task.isCompleted ? .orange : .green)
                                            }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                                .onDelete { offsets in
                                    deleteItems(for: section, at: offsets)
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
            .navigationTitle("nav.tasks".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
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
            .alert("alert.delete_task_title".localized, isPresented: $showingDeleteTaskAlert) {
                Button("action.cancel".localized, role: .cancel) { }
                Button("action.delete".localized, role: .destructive) {
                    if let task = taskToDelete {
                        deleteTask(task)
                    }
                }
            } message: {
                Text("alert.delete_task_message".localized(with: taskToDelete?.title ?? "this task"))
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
            .alert("alert.delete_task_title".localized, isPresented: $showingDeleteTaskAlert) {
                Button("action.cancel".localized, role: .cancel) { }
                Button("action.delete".localized, role: .destructive) {
                    if let task = taskToDelete {
                        deleteTask(task)
                    }
                }
            } message: {
                Text("alert.delete_task_message".localized(with: taskToDelete?.title ?? "this task"))
            }
            .onAppear {
                startOverdueTimer()
            }
            .onDisappear {
                stopOverdueTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh immediately when app comes to foreground
                refreshTrigger = Date()
            }
            .dismissKeyboardSafely()
    }
    
    // MARK: - Timer Functions for Real-time Overdue Updates
    private func startOverdueTimer() {
        // Stop any existing timer
        stopOverdueTimer()
        
        // Create a timer that fires every 30 seconds to check for overdue tasks
        overdueTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.refreshTrigger = Date()
            }
        }
    }
    
    private func stopOverdueTimer() {
        overdueTimer?.invalidate()
        overdueTimer = nil
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
                
                // Update badge count after task deletion
                NotificationManager.shared.handleTaskDeletion()
                
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
                
                // Update badge count after multiple task deletion
                NotificationManager.shared.handleTaskDeletion()
                
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
            .navigationTitle("action.postpone_task".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel".localized) {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save".localized) {
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
                                
                                // Update badge count after postponing task
                                NotificationManager.shared.handleTaskStateChange()
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
    let onTap: () -> Void
    let onEdit: (() -> Void)?
    let onTaskUpdated: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    
    private var cardBackground: Color {
        return colorScheme == .dark 
            ? Color(UIColor.systemGray6)
            : Color(UIColor.systemBackground)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Modern checkbox for completion status - isolated tap area
                ModernCheckboxView(
                    isCompleted: task.isCompleted
                ) {
                    toggleTaskCompletion()
                }
                .zIndex(1) // Ensure checkbox is above other elements for tap priority
                
                // Main content area with separate tap gesture
                VStack(alignment: .leading, spacing: 8) {
                    // Title row with priority and recurrence indicators moved to left
                    HStack(spacing: 8) {
                        // Priority indicator moved to left (before title)
                        if !task.isCompleted {
                            CompactPriorityIndicatorView(priority: task.priorityEnum)
                        }
                        
                        Text(task.title ?? "task.untitled".localized)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)
                        
                        Spacer()
                        
                        // Recurring task indicator
                        if task.hasRecurrence {
                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundColor(task.recurrenceTypeEnum.color)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                    
                    // Progress indicator for subtasks - simplified
                    if task.subtaskArray.count > 0 {
                        Text("\(task.completedSubtasks.count)/\(task.subtaskArray.count) subtasks")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tap gesture only on content area, not checkbox
                    onTap()
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
    
    private func toggleTaskCompletion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let wasCompleted = task.isCompleted
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            if !wasCompleted {
                // Completing the task
                task.handleTaskCompletion(in: viewContext)
                
                // Cancel notification since task is completed
                NotificationManager.shared.cancelNotification(for: task)
            } else {
                // Marking task as incomplete
                task.isCompleted = false
                task.updatedAt = Date()
                
                // Reschedule notification if task has due date
                if task.dueDate != nil {
                    NotificationManager.shared.scheduleNotification(for: task)
                }
            }
            
            do {
                try viewContext.save()
                
                // Update badge count immediately after task completion change
                NotificationManager.shared.handleTaskCompletion()
                
                onTaskUpdated?()
            } catch {
                print("Error toggling task completion: \(error)")
                // Rollback the change
                task.isCompleted = wasCompleted
                try? viewContext.save()
                
                // Update badge even after rollback to ensure consistency
                NotificationManager.shared.handleTaskCompletion()
            }
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
            return "sort.alphabetical".localized
        case .creationDate:
            return "sort.newest_first".localized
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
    @State private var selectedCategoryForTask: TaskCategory?
    @State private var showingDeleteCompletedAlert = false
    @State private var categoryToDeleteCompletedFrom: TaskCategory?
    
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
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    categoriesContent
                }
            } else {
                NavigationView {
                    categoriesContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
    
    private var categoriesContent: some View {
        VStack(spacing: 0) {
                // Search Section
                VStack(spacing: 0) {
                    UltraMinimalistSearchBar(
                        text: $searchText,
                        placeholder: "category.search_placeholder".localized
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                
                // Sort Section (separate from search)
                HStack {
                    Text("action.sort".localized)
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
                        }, onAddTask: {
                            // Add haptic feedback for long press
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            selectedCategoryForTask = category
                        })
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button("action.edit".localized) {
                                editingCategory = category
                            }
                            .tint(.blue)
                            
                            Button("action.delete_completed".localized) {
                                categoryToDeleteCompletedFrom = category
                                showingDeleteCompletedAlert = true
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .leading) {
                            Button("action.delete_category".localized, role: .destructive) {
                                categoryToDelete = category
                                showingDeleteCategoryAlert = true
                            }
                            
                            Button("action.delete_all_tasks".localized) {
                                categoryToDeleteTasksFrom = category
                                showingDeleteTasksAlert = true
                            }
                            .tint(.orange)
                        }
                    }
                    .onDelete(perform: deleteCategories)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("nav.categories".localized)
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
            .sheet(item: $selectedCategoryForTask) { category in
                TaskDetailView(category: category)
            }
            .alert("alert.delete_all_tasks_title".localized, isPresented: $showingDeleteTasksAlert) {
                Button("action.cancel".localized, role: .cancel) { }
                Button("action.delete_all_tasks".localized, role: .destructive) {
                    if let category = categoryToDeleteTasksFrom {
                        deleteAllTasksFromCategory(category)
                    }
                }
            } message: {
                Text("alert.delete_all_tasks_message".localized(with: categoryToDeleteTasksFrom?.name ?? "this category"))
            }
            .alert("alert.delete_category_title".localized, isPresented: $showingDeleteCategoryAlert) {
                Button("action.cancel".localized, role: .cancel) { }
                Button("action.delete_category".localized, role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
            } message: {
                let taskCount = categoryToDelete?.tasks?.count ?? 0
                let taskText = taskCount == 1 ? "task.singular".localized : "task.plural".localized
                Text("alert.delete_category_message".localized(with: categoryToDelete?.name ?? "this category") + " \(taskCount) \(taskText)? This action cannot be undone.")
            }
            .alert("alert.delete_completed_title".localized, isPresented: $showingDeleteCompletedAlert) {
                Button("action.cancel".localized, role: .cancel) { }
                Button("action.delete".localized, role: .destructive) {
                    if let category = categoryToDeleteCompletedFrom {
                        deleteCompletedTasksFromCategory(category)
                    }
                }
            } message: {
                Text("alert.delete_completed_message".localized(with: categoryToDeleteCompletedFrom?.name ?? "this category"))
            }
            .dismissKeyboardSafely()
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
    
    private func deleteCompletedTasksFromCategory(_ category: TaskCategory) {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Get all completed tasks from this category
            guard let allTasks = category.tasks as? Set<Task> else { 
                print("No tasks found in category")
                return 
            }
            
            let completedTasks = allTasks.filter { $0.isCompleted }
            
            guard !completedTasks.isEmpty else {
                print("No completed tasks found in category")
                // Still provide feedback for empty operation
                let warningFeedback = UINotificationFeedbackGenerator()
                warningFeedback.notificationOccurred(.warning)
                categoryToDeleteCompletedFrom = nil
                return
            }
            
            // Cancel notifications for completed tasks being deleted (should be none, but just in case)
            for task in completedTasks {
                NotificationManager.shared.cancelNotification(for: task)
            }
            
            // Delete all completed tasks
            for task in completedTasks {
                viewContext.delete(task)
            }
            
            do {
                try viewContext.save()
                print("Successfully deleted \(completedTasks.count) completed tasks from category: \(category.name ?? "Unknown")")
                
                // Additional haptic feedback for success
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
            } catch {
                print("Error deleting completed tasks from category: \(error)")
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
            
            // Reset state
            categoryToDeleteCompletedFrom = nil
        }
    }
}

struct CategoryCardView: View {
    let category: TaskCategory
    let onTap: () -> Void
    let onEdit: () -> Void
    let onAddTask: () -> Void
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
                                Text("\(taskCount) " + "stats.total".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if pendingTaskCount > 0 {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                    Text("\(pendingTaskCount) " + "stats.pending".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if completedTaskCount > 0 {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    Text("\(completedTaskCount) " + "stats.done".localized)
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
        .contextMenu {
            Button {
                onAddTask()
            } label: {
                Label("Add Task", systemImage: "plus")
            }
            
            Button {
                onEdit()
            } label: {
                Label("Edit Category", systemImage: "pencil")
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showCompletedTasks") private var showCompletedTasks = true
    @State private var showingClearDataAlert = false
    @State private var showingClearTasksAlert = false
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    settingsForm
                }
            } else {
                NavigationView {
                    settingsForm
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
    
    private var settingsForm: some View {
        Form {
                Section {
                    Toggle("settings.dark_mode".localized, isOn: $isDarkMode)
                } header: {
                    Text("settings.appearance".localized)
                }
                
                Section {
                    Picker("settings.language".localized, selection: $languageManager.currentLanguage) {
                        ForEach(LanguageManager.supportedLanguages) { language in
                            Text(language.name)
                                .tag(language.code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("settings.language".localized)
                }
                
                Section("settings.notifications".localized) {
                    Toggle("settings.enable_notifications".localized, isOn: $notificationsEnabled)
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
                
                Section("settings.tasks".localized) {
                    Toggle("settings.show_completed".localized, isOn: $showCompletedTasks)
                }
                
                
                Section("settings.data".localized) {
                    Button("settings.clear_tasks".localized) {
                        showingClearTasksAlert = true
                    }
                    .foregroundColor(.red)
                    
                    Button("settings.clear_data".localized) {
                        showingClearDataAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                Section("settings.about".localized) {
                    HStack {
                        Text("settings.version".localized)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("nav.settings".localized)
            .alert("alert.clear_data_title".localized, isPresented: $showingClearDataAlert) {
                Button("action.cancel".localized, role: .cancel) { }
                Button("action.delete".localized, role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("alert.clear_data_message".localized)
            }
            .alert("alert.clear_tasks_title".localized, isPresented: $showingClearTasksAlert) {
                Button("action.cancel".localized, role: .cancel) { }
                Button("action.delete".localized, role: .destructive) {
                    clearAllTasks()
                }
            } message: {
                Text("alert.clear_tasks_message".localized)
            }
            .dismissKeyboardOnFormTap()
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
                
                // Clear badge count after clearing all data
                NotificationManager.shared.handleTaskDeletion()
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
                
                // Clear badge count after clearing all tasks
                NotificationManager.shared.handleTaskDeletion()
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
                        DetailRow(title: "task.priority".localized, 
                                value: "\(task.priorityEnum.title) Priority",
                                icon: task.priorityEnum.systemImage,
                                color: task.priorityEnum.color)
                        
                        // Category
                        if let category = task.category {
                            DetailRow(title: "task.category".localized,
                                    value: category.name ?? "Unnamed",
                                    icon: category.icon ?? "folder",
                                    color: Color(hex: category.colorHex ?? "#007AFF"))
                        }
                        
                        // Due Date
                        if let dueDate = task.dueDate {
                            DetailRow(title: "task.due_date".localized,
                                    value: DateFormatter.taskDate.string(from: dueDate),
                                    icon: "calendar",
                                    color: dueDate < Date() && !task.isCompleted ? .red : .blue)
                        }
                        
                        // Status
                        DetailRow(title: "task.status".localized,
                                value: task.isCompleted ? "task.status_completed".localized : "task.status_pending".localized,
                                icon: task.isCompleted ? "checkmark.circle.fill" : "circle",
                                color: task.isCompleted ? .green : .orange)
                        
                        // Creation Date
                        if let createdAt = task.createdAt {
                            DetailRow(title: "task.created".localized,
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
            .navigationTitle("nav.task_details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.close".localized) {
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
            case .all: return "detail.all_tasks".localized
            case .completed: return "detail.completed_tasks".localized
            case .pending: return "detail.pending_tasks".localized
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
                            title: "stats.total".localized, 
                            value: "\(categoryTasks.count)", 
                            color: .blue, 
                            icon: "list.bullet",
                            isSelected: selectedFilter == .all,
                            onTap: { selectedFilter = .all }
                        )
                        StatCard(
                            title: "stats.completed".localized, 
                            value: "\(categoryTasks.filter { $0.isCompleted }.count)", 
                            color: .green, 
                            icon: "checkmark.circle.fill",
                            isSelected: selectedFilter == .completed,
                            onTap: { selectedFilter = .completed }
                        )
                        StatCard(
                            title: "stats.pending".localized, 
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
                                        Text(task.title ?? "task.untitled".localized)
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
            .navigationTitle("nav.category_details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.close".localized) {
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

// MARK: - Modern Checkbox Component
struct ModernCheckboxView: View {
    let isCompleted: Bool
    let onToggle: () -> Void
    
    @State private var isPressed = false
    @State private var bounceScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var rotationAngle: Double = 0.0
    
    var body: some View {
        Button(action: {
            performTapAnimation()
            onToggle()
        }) {
            ZStack {
                // Glow effect background
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                (isCompleted ? Color.blue : Color.gray).opacity(glowOpacity),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .animation(.easeOut(duration: 0.6), value: glowOpacity)
                
                // Main checkbox icon with enhanced animations
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isCompleted ? .blue : .gray)
                    .scaleEffect(isPressed ? 0.85 : bounceScale)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCompleted)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: bounceScale)
                    .animation(.easeInOut(duration: 0.3), value: rotationAngle)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 44, height: 44) // Larger tap area for better accessibility
        .contentShape(Rectangle()) // Ensure the entire frame is tappable
        .pressEvents(
            onPress: {
                isPressed = true
            },
            onRelease: {
                isPressed = false
            }
        )
    }
    
    private func performTapAnimation() {
        // Enhanced haptic feedback based on completion state
        let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = isCompleted ? .light : .medium
        let impactFeedback = UIImpactFeedbackGenerator(style: hapticStyle)
        impactFeedback.impactOccurred()
        
        // Bounce animation sequence
        withAnimation(.easeOut(duration: 0.1)) {
            bounceScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bounceScale = 1.0
            }
        }
        
        // Glow pulse effect
        withAnimation(.easeOut(duration: 0.2)) {
            glowOpacity = 0.4
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                glowOpacity = 0.0
            }
        }
        
        // Subtle rotation for completion
        if !isCompleted {
            withAnimation(.easeInOut(duration: 0.3)) {
                rotationAngle = 360
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                rotationAngle = 0 // Reset for next animation
            }
        }
    }
}

// MARK: - Compact Priority Indicator (moved to left)
struct CompactPriorityIndicatorView: View {
    let priority: TaskPriority
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(priority.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(priority.color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(priority.color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

