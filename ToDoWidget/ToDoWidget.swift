import WidgetKit
import SwiftUI
import CoreData

struct ToDoWidget: Widget {
    let kind: String = "ToDoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskProvider()) { entry in
            ToDoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tasks")
        .description("View your upcoming tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskWidgetData]
    let configuration: TaskConfiguration
}

struct TaskConfiguration {
    let showCompleted: Bool
    let maxTasks: Int
    let categoryFilter: String?
}

struct TaskWidgetData: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let priority: Int
    let dueDate: Date?
    let categoryName: String?
    let categoryColor: String?
    
    var priorityColor: Color {
        switch priority {
        case 2: return .red
        case 1: return .orange
        default: return .green
        }
    }
}

struct TaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            tasks: sampleTasks,
            configuration: TaskConfiguration(
                showCompleted: false,
                maxTasks: 5,
                categoryFilter: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> ()) {
        let entry = TaskEntry(
            date: Date(),
            tasks: sampleTasks,
            configuration: TaskConfiguration(
                showCompleted: false,
                maxTasks: 5,
                categoryFilter: nil
            )
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> ()) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        
        fetchTasks { tasks in
            let entry = TaskEntry(
                date: currentDate,
                tasks: tasks,
                configuration: TaskConfiguration(
                    showCompleted: false,
                    maxTasks: context.family == .systemSmall ? 3 : 8,
                    categoryFilter: nil
                )
            )
            
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
    
    private func fetchTasks(completion: @escaping ([TaskWidgetData]) -> Void) {
        let context = PersistenceController.shared.container.viewContext
        
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)
        ]
        request.fetchLimit = 10
        
        do {
            let tasks = try context.fetch(request)
            let widgetTasks = tasks.map { task in
                TaskWidgetData(
                    id: task.id ?? UUID(),
                    title: task.title ?? "Untitled Task",
                    isCompleted: task.isCompleted,
                    priority: Int(task.priority),
                    dueDate: task.dueDate,
                    categoryName: task.category?.name,
                    categoryColor: task.category?.colorHex
                )
            }
            completion(widgetTasks)
        } catch {
            print("Widget fetch error: \(error)")
            completion([])
        }
    }
    
    private var sampleTasks: [TaskWidgetData] {
        [
            TaskWidgetData(
                id: UUID(),
                title: "Complete project proposal",
                isCompleted: false,
                priority: 2,
                dueDate: Date(),
                categoryName: "Work",
                categoryColor: "#007AFF"
            ),
            TaskWidgetData(
                id: UUID(),
                title: "Buy groceries",
                isCompleted: false,
                priority: 1,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                categoryName: "Personal",
                categoryColor: "#FF6B6B"
            ),
            TaskWidgetData(
                id: UUID(),
                title: "Call mom",
                isCompleted: false,
                priority: 0,
                dueDate: nil,
                categoryName: "Personal",
                categoryColor: "#FF6B6B"
            )
        ]
    }
}

struct ToDoWidgetEntryView: View {
    var entry: TaskProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: TaskEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Spacer()
                
                Text("\(entry.tasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if entry.tasks.isEmpty {
                Spacer()
                
                Text("No tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(3)) { task in
                    TaskRowWidget(task: task, isCompact: true)
                }
                
                if entry.tasks.count > 3 {
                    Text("+ \(entry.tasks.count - 3) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct MediumWidgetView: View {
    let entry: TaskEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Tasks")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(entry.tasks.count) remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checklist")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            
            if entry.tasks.isEmpty {
                HStack {
                    Spacer()
                    Text("All tasks completed! 🎉")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ForEach(entry.tasks.prefix(4)) { task in
                    TaskRowWidget(task: task, isCompact: false)
                }
                
                if entry.tasks.count > 4 {
                    Text("+ \(entry.tasks.count - 4) more tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct LargeWidgetView: View {
    let entry: TaskEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("My Tasks")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(entry.tasks.count) tasks remaining")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checklist")
                    .foregroundColor(.blue)
                    .font(.largeTitle)
            }
            
            if entry.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("All Done!")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("You've completed all your tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(entry.tasks.prefix(8)) { task in
                            TaskRowWidget(task: task, isCompact: false)
                        }
                    }
                }
                
                if entry.tasks.count > 8 {
                    Text("+ \(entry.tasks.count - 8) more tasks in app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct TaskRowWidget: View {
    let task: TaskWidgetData
    let isCompact: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(task.priorityColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(isCompact ? .caption : .caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if !isCompact, let categoryName = task.categoryName {
                    Text(categoryName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let dueDate = task.dueDate {
                Text(DateFormatter.widgetDate.string(from: dueDate))
                    .font(.caption2)
                    .foregroundColor(dueDate < Date() ? .red : .secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

extension DateFormatter {
    static let widgetDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

struct ToDoWidget_Previews: PreviewProvider {
    static var previews: some View {
        ToDoWidgetEntryView(entry: TaskEntry(
            date: Date(),
            tasks: [],
            configuration: TaskConfiguration(
                showCompleted: false,
                maxTasks: 5,
                categoryFilter: nil
            )
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}