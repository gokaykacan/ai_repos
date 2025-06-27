import Foundation
import Combine
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isDarkModeEnabled: Bool
    @Published var defaultPriority: TaskPriority
    @Published var defaultDueDateOffset: Int
    @Published var notificationsEnabled: Bool
    @Published var hapticFeedbackEnabled: Bool
    @Published var showCompletedTasks: Bool
    @Published var taskSortOrder: TaskSortOrder
    
    @Published var showingNotificationPermissionAlert = false
    @Published var notificationPermissionStatus: NotificationPermissionStatus = .notDetermined
    
    private let userPreferences: UserPreferencesProtocol
    private let notificationManager: NotificationManagerProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    enum NotificationPermissionStatus {
        case notDetermined
        case denied
        case authorized
    }
    
    init(
        userPreferences: UserPreferencesProtocol,
        notificationManager: NotificationManagerProtocol
    ) {
        self.userPreferences = userPreferences
        self.notificationManager = notificationManager
        
        self.isDarkModeEnabled = userPreferences.isDarkModeEnabled
        self.defaultPriority = userPreferences.defaultPriority
        self.defaultDueDateOffset = userPreferences.defaultDueDateOffset
        self.notificationsEnabled = userPreferences.notificationsEnabled
        self.hapticFeedbackEnabled = userPreferences.hapticFeedbackEnabled
        self.showCompletedTasks = userPreferences.showCompletedTasks
        self.taskSortOrder = userPreferences.taskSortOrder
        
        setupBindings()
        checkNotificationPermission()
    }
    
    private func setupBindings() {
        $isDarkModeEnabled
            .sink { [weak self] value in
                self?.userPreferences.isDarkModeEnabled = value
            }
            .store(in: &cancellables)
        
        $defaultPriority
            .sink { [weak self] value in
                self?.userPreferences.defaultPriority = value
            }
            .store(in: &cancellables)
        
        $defaultDueDateOffset
            .sink { [weak self] value in
                self?.userPreferences.defaultDueDateOffset = value
            }
            .store(in: &cancellables)
        
        $notificationsEnabled
            .sink { [weak self] value in
                self?.userPreferences.notificationsEnabled = value
                if value {
                    self?.requestNotificationPermission()
                }
            }
            .store(in: &cancellables)
        
        $hapticFeedbackEnabled
            .sink { [weak self] value in
                self?.userPreferences.hapticFeedbackEnabled = value
            }
            .store(in: &cancellables)
        
        $showCompletedTasks
            .sink { [weak self] value in
                self?.userPreferences.showCompletedTasks = value
            }
            .store(in: &cancellables)
        
        $taskSortOrder
            .sink { [weak self] value in
                self?.userPreferences.taskSortOrder = value
            }
            .store(in: &cancellables)
    }
    
    private func checkNotificationPermission() {
        Task {
            let current = await UNUserNotificationCenter.current().notificationSettings()
            
            await MainActor.run {
                switch current.authorizationStatus {
                case .notDetermined:
                    self.notificationPermissionStatus = .notDetermined
                case .denied:
                    self.notificationPermissionStatus = .denied
                case .authorized, .provisional:
                    self.notificationPermissionStatus = .authorized
                case .ephemeral:
                    self.notificationPermissionStatus = .authorized
                @unknown default:
                    self.notificationPermissionStatus = .notDetermined
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        guard notificationPermissionStatus == .notDetermined else {
            if notificationPermissionStatus == .denied {
                showingNotificationPermissionAlert = true
            }
            return
        }
        
        notificationManager.requestPermission()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.checkNotificationPermission()
        }
    }
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    func resetAllSettings() {
        isDarkModeEnabled = false
        defaultPriority = .medium
        defaultDueDateOffset = 0
        notificationsEnabled = true
        hapticFeedbackEnabled = true
        showCompletedTasks = true
        taskSortOrder = .createdDate
    }
    
    func clearAllData() {
        Task {
            await notificationManager.cancelAllPendingNotifications()
        }
    }
}