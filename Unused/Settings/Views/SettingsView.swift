import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var viewModel = SettingsViewModelWrapper()
    
    var body: some View {
        NavigationView {
            Form {
                if let vm = viewModel.wrappedViewModel {
                    appearanceSection(vm)
                    defaultsSection(vm)
                    notificationsSection(vm)
                    behaviorSection(vm)
                    dataSection(vm)
                    aboutSection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Notifications Disabled", isPresented: .constant(viewModel.wrappedViewModel?.showingNotificationPermissionAlert == true)) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    viewModel.wrappedViewModel?.openAppSettings()
                }
            } message: {
                Text("Please enable notifications in Settings to receive task reminders.")
            }
        }
        .onAppear {
            if viewModel.wrappedViewModel == nil {
                viewModel.wrappedViewModel = container.makeSettingsViewModel()
            }
        }
    }
    
    private func appearanceSection(_ vm: SettingsViewModel) -> some View {
        Section("Appearance") {
            Toggle("Dark Mode", isOn: .constant(vm.isDarkModeEnabled))
                .onChange(of: vm.isDarkModeEnabled) { value in
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.windows.first?.overrideUserInterfaceStyle = value ? .dark : .light
                    }
                }
        }
    }
    
    private func defaultsSection(_ vm: SettingsViewModel) -> some View {
        Section("Default Settings") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Priority")
                    .font(.caption)
                    .foregroundColor(.secondaryLabel)
                
                // Using a simplified picker since we can't bind directly
                HStack {
                    ForEach(TaskPriority.allCases) { priority in
                        Button(priority.title) {
                            vm.defaultPriority = priority
                        }
                        .foregroundColor(vm.defaultPriority == priority ? .white : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(vm.defaultPriority == priority ? Color.blue : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
            
            HStack {
                Text("Default Due Date")
                Spacer()
                Text(vm.defaultDueDateOffset == 0 ? "None" : "+\(vm.defaultDueDateOffset) days")
                    .foregroundColor(.secondaryLabel)
            }
        }
    }
    
    private func notificationsSection(_ vm: SettingsViewModel) -> some View {
        Section("Notifications") {
            Toggle("Enable Notifications", isOn: .constant(vm.notificationsEnabled))
            
            if vm.notificationsEnabled {
                HStack {
                    Text("Permission Status")
                    Spacer()
                    Text(permissionStatusText(vm.notificationPermissionStatus))
                        .foregroundColor(vm.notificationPermissionStatus == .authorized ? .green : .red)
                }
            }
        }
    }
    
    private func behaviorSection(_ vm: SettingsViewModel) -> some View {
        Section("Behavior") {
            Toggle("Haptic Feedback", isOn: .constant(vm.hapticFeedbackEnabled))
            Toggle("Show Completed Tasks", isOn: .constant(vm.showCompletedTasks))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Sort Order")
                    .font(.caption)
                    .foregroundColor(.secondaryLabel)
                
                Text(vm.taskSortOrder.title)
                    .foregroundColor(.secondaryLabel)
            }
        }
    }
    
    private func dataSection(_ vm: SettingsViewModel) -> some View {
        Section("Data Management") {
            Button("Reset All Settings") {
                vm.resetAllSettings()
            }
            .foregroundColor(.orange)
            
            Button("Clear All Data") {
                vm.clearAllData()
            }
            .foregroundColor(.red)
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondaryLabel)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .foregroundColor(.secondaryLabel)
            }
            
            Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
            
            Button("Contact Support") {
                if let url = URL(string: "mailto:support@moderntodoapp.com") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private func permissionStatusText(_ status: SettingsViewModel.NotificationPermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Requested"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        }
    }
}

// Wrapper class to handle optional SettingsViewModel
class SettingsViewModelWrapper: ObservableObject {
    @Published var wrappedViewModel: SettingsViewModel?
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(DependencyContainer())
    }
}