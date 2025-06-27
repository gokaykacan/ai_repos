import SwiftUI
import CoreData
import UserNotifications

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Tasks")
                }
                .tag(0)
            
            CategoriesView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("Categories")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddTask = false
    @State private var selectedTask: Task?
    @State private var searchText = ""
    @State private var selectedCategory: TaskCategory?
    @AppStorage("showCompletedTasks") private var showCompletedTasks = true
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Task.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)
        ],
        animation: .default)
    private var tasks: FetchedResults<Task>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskCategory.name, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<TaskCategory>
    
    var filteredTasks: [Task] {
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
                    ForEach(filteredTasks, id: \.self) { task in
                        TaskRowView(task: task) {
                            selectedTask = task
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                TaskDetailView()
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredTasks[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting task: \(error)")
            }
        }
    }
}

struct TaskRowView: View {
    let task: Task
    let onTap: () -> Void
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                toggleCompletion()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title ?? "Untitled Task")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                    
                    Spacer()
                    
                    // Priority indicator
                    Image(systemName: task.priorityEnum.systemImage)
                        .font(.caption)
                        .foregroundColor(task.priorityEnum.color)
                }
                
                HStack {
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
                    
                    Spacer()
                    
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
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                deleteTask()
            }
            
            Button("Edit") {
                onTap()
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button(task.isCompleted ? "Incomplete" : "Complete") {
                toggleCompletion()
            }
            .tint(task.isCompleted ? .orange : .green)
        }
    }
    
    private func toggleCompletion() {
        withAnimation {
            task.isCompleted.toggle()
            task.updatedAt = Date()
            
            do {
                try viewContext.save()
                
                // Handle notification based on completion status
                if notificationsEnabled {
                    if task.isCompleted {
                        // Cancel notification when task is completed
                        NotificationManager.shared.cancelNotification(for: task)
                    } else if task.dueDate != nil {
                        // Reschedule notification when task is marked incomplete again
                        NotificationManager.shared.scheduleNotification(for: task)
                    }
                }
            } catch {
                print("Error toggling task completion: \(error)")
            }
        }
    }
    
    private func deleteTask() {
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
}

struct CategoriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddCategory = false
    @State private var selectedCategory: TaskCategory?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskCategory.sortOrder, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<TaskCategory>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(categories, id: \.self) { category in
                    CategoryRowView(category: category) {
                        selectedCategory = category
                    }
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCategory = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                CategoryDetailView()
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category)
            }
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        withAnimation {
            offsets.map { categories[$0] }.forEach(viewContext.delete)
            
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
    
    var taskCount: Int {
        category.tasks?.count ?? 0
    }
    
    var body: some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showCompletedTasks") private var showCompletedTasks = true
    @State private var showingClearDataAlert = false
    
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, CoreDataStack.shared.container.viewContext)
    }
}