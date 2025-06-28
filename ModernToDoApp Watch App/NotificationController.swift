import WatchKit
import SwiftUI
import UserNotifications

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    var taskTitle: String = "Task Reminder"
    var taskNotes: String = "You have a task due soon"
    
    override var body: NotificationView {
        return NotificationView(taskTitle: taskTitle, taskNotes: taskNotes)
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
        if let title = userInfo["taskTitle"] as? String {
            self.taskTitle = title
        }
        if let notes = userInfo["taskNotes"] as? String {
            self.taskNotes = notes
        }
        // You might also want to pass the task ID for actions
    }
}

struct NotificationView: View {
    let taskTitle: String
    let taskNotes: String
    
    init(taskTitle: String, taskNotes: String) {
        self.taskTitle = taskTitle
        self.taskNotes = taskNotes
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text(taskTitle)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(taskNotes)
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
        NotificationView(taskTitle: "Sample Task", taskNotes: "This is a sample note for the task.")
    }
}