import CoreData
import CloudKit
import Foundation

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    lazy var container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "TaskModel")
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            print("Failed to pin viewContext to the current generation: \(error)")
        }
        
        return container
    }()
    
    private init() {}
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
        save()
    }
}

extension PersistenceController {
    static var preview: PersistenceController = {
        let controller = PersistenceController()
        let context = controller.container.viewContext
        
        let sampleCategory = TaskCategory(context: context)
        sampleCategory.id = UUID()
        sampleCategory.name = "Work"
        sampleCategory.colorHex = "#007AFF"
        sampleCategory.icon = "briefcase"
        sampleCategory.createdAt = Date()
        
        let sampleTask = Task(context: context)
        sampleTask.id = UUID()
        sampleTask.title = "Complete project proposal"
        sampleTask.notes = "Need to finish the Q4 project proposal by end of week"
        sampleTask.priority = 2
        sampleTask.isCompleted = false
        sampleTask.createdAt = Date()
        sampleTask.dueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        sampleTask.category = sampleCategory
        
        do {
            try context.save()
        } catch {
            print("Preview save error: \(error)")
        }
        
        return controller
    }()
}