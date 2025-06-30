import SwiftUI
import CoreData
import UserNotifications

@main
struct ModernToDoAppApp: App {
    let persistenceController = CoreDataStack.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Request notification permissions
        NotificationManager.shared.requestPermission()
        
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
                        NotificationManager.shared.updateApplicationBadgeNumber()
                    } else if newPhase == .active {
                        NotificationManager.shared.clearAppBadge()
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