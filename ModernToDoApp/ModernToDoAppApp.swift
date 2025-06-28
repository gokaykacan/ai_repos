import SwiftUI
import CoreData
import UserNotifications

@main
struct ModernToDoAppApp: App {
    let persistenceController = CoreDataStack.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    init() {
        // Request notification permissions
        NotificationManager.shared.requestPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onChange(of: isDarkMode) { newValue in
                    applyDarkModePreference(newValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Clear badge when app comes to foreground
                    NotificationManager.shared.clearAppBadge()
                }
        }
    }
    
    private func applyDarkModePreference(_ isDark: Bool) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.first?.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
        }
    }
}

// Simple Core Data stack
class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TaskModel")
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
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
}