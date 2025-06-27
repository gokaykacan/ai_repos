import CoreData
import Foundation
import Combine

class PaginatedTaskRepository: ObservableObject {
    private let coreDataStack: PerformanceOptimizedCoreDataStack
    private let pageSize: Int
    private let performanceMonitor = CoreDataPerformanceMonitor.shared
    
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var hasMorePages = true
    
    private var currentPage = 0
    private var loadedObjectIDs: Set<NSManagedObjectID> = []
    
    init(coreDataStack: PerformanceOptimizedCoreDataStack = .shared, pageSize: Int = 50) {
        self.coreDataStack = coreDataStack
        self.pageSize = pageSize
    }
    
    // MARK: - Paginated Loading
    
    func loadInitialTasks(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) async {
        await MainActor.run {
            isLoading = true
            tasks.removeAll()
            loadedObjectIDs.removeAll()
            currentPage = 0
            hasMorePages = true
        }
        
        await loadNextPage(predicate: predicate, sortDescriptors: sortDescriptors)
    }
    
    func loadNextPage(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) async {
        guard hasMorePages && !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        let fetchedTasks = await performanceMonitor.measureFetch(operation: "loadPage_\(currentPage)") {
            return await fetchTasks(
                predicate: predicate,
                sortDescriptors: sortDescriptors,
                offset: currentPage * pageSize,
                limit: pageSize
            )
        }
        
        await MainActor.run {
            let newTasks = fetchedTasks.filter { !loadedObjectIDs.contains($0.objectID) }
            
            tasks.append(contentsOf: newTasks)
            loadedObjectIDs.formUnion(newTasks.map { $0.objectID })
            
            hasMorePages = fetchedTasks.count == pageSize
            currentPage += 1
            isLoading = false
            
            // Cache loaded tasks
            newTasks.forEach { TaskCacheManager.shared.cacheTask($0) }
        }
    }
    
    private func fetchTasks(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        offset: Int,
        limit: Int
    ) async -> [Task] {
        return await coreDataStack.backgroundContext.perform {
            let request: NSFetchRequest<Task> = Task.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors
            request.fetchOffset = offset
            request.fetchLimit = limit
            
            // Optimize fetch
            request.includesPendingChanges = false
            request.shouldRefreshRefetchedObjects = false
            request.relationshipKeyPathsForPrefetching = ["category", "subtasks"]
            
            do {
                return try self.coreDataStack.backgroundContext.fetch(request)
            } catch {
                print("Error fetching tasks: \(error)")
                return []
            }
        }
    }
    
    // MARK: - Search with Pagination
    
    func searchTasks(query: String, page: Int = 0) async -> [Task] {
        let predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
            query, query
        )
        
        return await performanceMonitor.measureFetch(operation: "searchTasks") {
            return await fetchTasks(
                predicate: predicate,
                sortDescriptors: [
                    NSSortDescriptor(keyPath: \Task.isCompleted, ascending: true),
                    NSSortDescriptor(keyPath: \Task.priority, ascending: false),
                    NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)
                ],
                offset: page * pageSize,
                limit: pageSize
            )
        }
    }
    
    // MARK: - Efficient Updates
    
    func updateTask(_ task: Task, changes: [String: Any]) async {
        await coreDataStack.backgroundContext.perform {
            let backgroundTask = self.coreDataStack.backgroundContext.object(with: task.objectID) as? Task
            
            for (key, value) in changes {
                backgroundTask?.setValue(value, forKey: key)
            }
            
            backgroundTask?.updatedAt = Date()
            
            do {
                try self.coreDataStack.backgroundContext.save()
            } catch {
                print("Error updating task: \(error)")
            }
        }
    }
    
    func batchUpdateTasks(predicate: NSPredicate, changes: [String: Any]) async {
        do {
            try await coreDataStack.performBatchUpdate(
                entityType: Task.self,
                predicate: predicate,
                propertiesToUpdate: changes
            )
        } catch {
            print("Error batch updating tasks: \(error)")
        }
    }
    
    // MARK: - Efficient Deletion
    
    func deleteTask(_ task: Task) async {
        await coreDataStack.backgroundContext.perform {
            let backgroundTask = self.coreDataStack.backgroundContext.object(with: task.objectID) as? Task
            if let backgroundTask = backgroundTask {
                self.coreDataStack.backgroundContext.delete(backgroundTask)
                
                do {
                    try self.coreDataStack.backgroundContext.save()
                } catch {
                    print("Error deleting task: \(error)")
                }
            }
        }
        
        // Update local cache
        await MainActor.run {
            tasks.removeAll { $0.objectID == task.objectID }
            loadedObjectIDs.remove(task.objectID)
        }
    }
    
    func batchDeleteTasks(predicate: NSPredicate) async {
        do {
            try await coreDataStack.performBatchDelete(
                entityType: Task.self,
                predicate: predicate
            )
            
            // Refresh local data
            await loadInitialTasks()
        } catch {
            print("Error batch deleting tasks: \(error)")
        }
    }
    
    // MARK: - Memory Management
    
    func clearCache() {
        tasks.removeAll()
        loadedObjectIDs.removeAll()
        currentPage = 0
        hasMorePages = true
    }
}

// MARK: - Optimized Fetch Requests

extension PaginatedTaskRepository {
    
    static func createOptimizedFetchRequest(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = [],
        limit: Int = 50,
        prefetchKeyPaths: [String] = ["category", "subtasks"]
    ) -> NSFetchRequest<Task> {
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        request.fetchLimit = limit
        request.relationshipKeyPathsForPrefetching = prefetchKeyPaths
        request.includesPendingChanges = false
        request.shouldRefreshRefetchedObjects = false
        return request
    }
    
    static func createCountRequest(predicate: NSPredicate? = nil) -> NSFetchRequest<Task> {
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.predicate = predicate
        request.includesSubentities = false
        request.includesPendingChanges = false
        return request
    }
}