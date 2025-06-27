import Foundation
import CoreData
import Combine

final class CategoryRepository: CategoryRepositoryProtocol {
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
    }
    
    func fetchCategories() async -> [TaskCategory] {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<TaskCategory> = TaskCategory.fetchRequest()
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \TaskCategory.sortOrder, ascending: true),
                    NSSortDescriptor(keyPath: \TaskCategory.name, ascending: true)
                ]
                
                do {
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    print("Error fetching categories: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func createCategory(name: String, colorHex: String, icon: String) async -> TaskCategory {
        return await withCheckedContinuation { continuation in
            context.perform {
                let category = TaskCategory(context: self.context)
                category.name = name
                category.colorHex = colorHex
                category.icon = icon
                
                let existingCategories = try? self.context.fetch(TaskCategory.fetchRequest())
                category.sortOrder = Int16(existingCategories?.count ?? 0)
                
                self.persistenceController.save()
                continuation.resume(returning: category)
            }
        }
    }
    
    func updateCategory(_ category: TaskCategory) async {
        await withCheckedContinuation { continuation in
            context.perform {
                self.persistenceController.save()
                continuation.resume()
            }
        }
    }
    
    func deleteCategory(_ category: TaskCategory) async {
        await withCheckedContinuation { continuation in
            context.perform {
                for task in category.taskArray {
                    task.category = nil
                }
                
                self.context.delete(category)
                self.persistenceController.save()
                continuation.resume()
            }
        }
    }
    
    func createCategoryPublisher() -> AnyPublisher<[TaskCategory], Never> {
        let request: NSFetchRequest<TaskCategory> = TaskCategory.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskCategory.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \TaskCategory.name, ascending: true)
        ]
        
        return NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .map { _ in
                do {
                    return try self.context.fetch(request)
                } catch {
                    print("Error fetching categories: \(error)")
                    return []
                }
            }
            .prepend([])
            .eraseToAnyPublisher()
    }
}