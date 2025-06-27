import SwiftUI
import WatchKit

@main
struct ModernToDoApp_Watch_AppApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView()
        }

        WKNotificationScene(controller: NotificationController.self, category: "TASK_REMINDER")
    }
}