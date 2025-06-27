import Foundation
import CoreData
import Combine

final class TaskRepository: TaskRepositoryProtocol {
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
    }
    
    // MARK: - Fetch Operations
    func fetchTasks() async -> [Task] {
        await performFetch(predicate: nil, sortDescriptors: defaultSortDescriptors())
    }
    
    func fetchTasks(for category: TaskCategory) async -> [Task] {
        let predicate = NSPredicate(format: "category == %@", category)
        return await performFetch(predicate: predicate, sortDescriptors: defaultSortDescriptors())
    }
    
    func fetchTasks(predicate: NSPredicate) async -> [Task] {
        await performFetch(predicate: predicate, sortDescriptors: defaultSortDescriptors())
    }
    
    func fetchCompletedTasks() async -> [Task] {
        let predicate = NSPredicate(format: "isCompleted == YES")
        return await performFetch(predicate: predicate, sortDescriptors: defaultSortDescriptors())
    }
    
    func fetchIncompleteTasks() async -> [Task] {
        let predicate = NSPredicate(format: "isCompleted == NO")
        return await performFetch(predicate: predicate, sortDescriptors: defaultSortDescriptors())
    }
    
    func fetchOverdueTasks() async -> [Task] {
        let predicate = NSPredicate(format: "dueDate < %@ AND isCompleted == NO", Date() as NSDate)
        return await performFetch(predicate: predicate, sortDescriptors: defaultSortDescriptors())
    }
    
    func fetchTasksDueToday() async -> [Task] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        return await performFetch(predicate: predicate, sortDescriptors: defaultSortDescriptors())
    }
    
    func fetchTasksDueTomorrow() async -> [Task] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let startOfTomorrow = Calendar.current.startOfDay(for: tomorrow)
        let endOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfTomorrow)!
        
        let predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfTomorrow as NSDate, endOfTomorrow as NSDate)
        return await performFetch(predicate: predicate, sortDescriptors: defaultSortDescriptors())
    }
    
    func searchTasks(query: String) async -> [Task] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR notes CONTAINS[cd] %@", query, query)
        return await performFetch(predicate: predicate, sortDescriptors: defaultSortDescriptors())
    }
    
    // MARK: - CRUD Operations
    func createTask(
        title: String,
        notes: String? = nil,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        category: TaskCategory? = nil,
        parentTask: Task? = nil
    ) async -> Task {
        return await withCheckedContinuation { continuation in
            context.perform {
                let task = Task(context: self.context)
                task.title = title
                task.notes = notes
                task.priorityEnum = priority
                task.dueDate = dueDate
                task.category = category
                task.parentTask = parentTask
                
                self.persistenceController.save()
                continuation.resume(returning: task)
            }
        }
    }
    
    func updateTask(_ task: Task) async {
        await withCheckedContinuation { continuation in
            context.perform {
                self.persistenceController.save()
                continuation.resume()
            }
        }
    }
    
    func deleteTask(_ task: Task) async {
        await withCheckedContinuation { continuation in
            context.perform {
                self.context.delete(task)
                self.persistenceController.save()
                continuation.resume()
            }
        }
    }
    
    func toggleTaskCompletion(_ task: Task) async {
        await withCheckedContinuation { continuation in
            context.perform {
                task.isCompleted.toggle()
                if task.isCompleted {
                    for subtask in task.subtaskArray {
                        subtask.isCompleted = true
                    }
                }
                self.persistenceController.save()
                continuation.resume()
            }
        }
    }
    
    // MARK: - Publishers
    func createTaskPublisher() -> AnyPublisher<[Task], Never> {
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.sortDescriptors = defaultSortDescriptors()
        
        return NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .map { _ in
                do {
                    return try self.context.fetch(request)
                } catch {
                    print("Error fetching tasks: \(error)")
                    return []
                }
            }
            .prepend([])
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    private func performFetch(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]) async -> [Task] {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<Task> = Task.fetchRequest()
                request.predicate = predicate
                request.sortDescriptors = sortDescriptors
                
                do {
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    print("Error fetching tasks: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func defaultSortDescriptors() -> [NSSortDescriptor] {
        [
            NSSortDescriptor(keyPath: \Task.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)
        ]
    }
}