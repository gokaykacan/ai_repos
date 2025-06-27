import WatchKit
import SwiftUI
import UserNotifications

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    
    override var body: NotificationView {
        return NotificationView()
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
    
    override func didReceive(_ notification: UNNotification) {
        // Extract notification data
        let userInfo = notification.request.content.userInfo
        let taskTitle = userInfo["taskTitle"] as? String ?? "Task Reminder"
        
        // Update the notification view with the task data
        // This would be passed to the NotificationView
    }
}

struct NotificationView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("Task Reminder")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("You have a task due soon")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Mark Done") {
                    // Handle mark as done
                    WKInterfaceDevice.current().play(.success)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Snooze") {
                    // Handle snooze
                    WKInterfaceDevice.current().play(.click)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
    }
}

struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationView()
    }
}