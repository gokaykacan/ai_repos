import SwiftUI
import CoreData
import UserNotifications

// AppDelegate to handle notification actions
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let actionIdentifier = response.actionIdentifier
        let notificationIdentifier = response.notification.request.identifier
        
        // Parse task ID from notification identifier (it should be task.id.uuidString)
        guard let taskUUID = UUID(uuidString: notificationIdentifier) else {
            completionHandler()
            return
        }
        
        let context = CoreDataStack.shared.container.viewContext
        
        // Find the task
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", taskUUID as CVarArg)
        
        do {
            let tasks = try context.fetch(fetchRequest)
            guard let task = tasks.first else {
                completionHandler()
                return
            }
            
            switch actionIdentifier {
            case "COMPLETE_ACTION":
                // Mark task as completed
                task.handleTaskCompletion(in: context)
                NotificationManager.shared.cancelNotification(for: task)
                
            case "POSTPONE_ACTION":
                // Postpone task by 1 hour
                if let currentDueDate = task.dueDate {
                    let newDueDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDueDate) ?? currentDueDate
                    task.dueDate = newDueDate
                    task.updatedAt = Date()
                    
                    // Reschedule notification
                    NotificationManager.shared.updateNotification(for: task)
                }
                
            case "VIEW_ACTION", UNNotificationDefaultActionIdentifier:
                // Open app to view task - this will happen automatically
                break
                
            default:
                break
            }
            
            // Save changes
            try context.save()
            
        } catch {
            print("Error handling notification action: \(error)")
        }
        
        completionHandler()
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct ModernToDoAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let persistenceController = CoreDataStack.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize notification manager with improved system
        NotificationManager.shared.initialize()
        
        // Initialize language manager (this must be done early)
        _ = LanguageManager.shared
        
        // Initialize dark mode based on system appearance on first launch
        initializeDarkModePreference()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // Apply stored dark mode preference on app startup
                    applyStoredDarkModePreference()
                }
                .onChange(of: isDarkMode) { newValue in
                    applyDarkModePreference(newValue)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        NotificationManager.shared.updateBadgeCount()
                    } else if newPhase == .active {
                        // Notification manager automatically handles app active state
                        // Reapply dark mode preference when app becomes active
                        applyStoredDarkModePreference()
                    }
                }
        }
    }
    
    private func initializeDarkModePreference() {
        // Only initialize on first launch
        if isFirstLaunch {
            // Detect current system appearance using multiple methods for reliability
            let systemIsDark = detectSystemDarkMode()
            
            // Set initial dark mode preference to match system
            isDarkMode = systemIsDark
            
            // Mark that we've completed first launch initialization
            isFirstLaunch = false
            
            print("First launch detected. Initialized dark mode to match system appearance: \(systemIsDark ? "Dark" : "Light")")
        }
    }
    
    private func applyStoredDarkModePreference() {
        // Apply the current stored preference immediately on app startup
        // This ensures the app UI matches the toggle state on every launch
        print("Applying stored dark mode preference: \(isDarkMode ? "Dark" : "Light")")
        applyDarkModePreference(isDarkMode)
    }
    
    private func detectSystemDarkMode() -> Bool {
        // Method 1: Try to get from current trait collection
        if UITraitCollection.current.userInterfaceStyle == .dark {
            return true
        }
        
        // Method 2: Check if we can get it from the current window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.traitCollection.userInterfaceStyle == .dark
        }
        
        // Method 3: Fallback to checking main screen traits (iOS 13+)
        if #available(iOS 13.0, *) {
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
        
        // Default fallback to light mode
        return false
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