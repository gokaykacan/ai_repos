import Foundation
import SwiftUI
import UIKit

public class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: String {
        didSet {
            let oldValue = UserDefaults.standard.string(forKey: "AppLanguage")
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            // Show restart alert if language was actually changed
            if oldValue != nil && oldValue != currentLanguage {
                showRestartAlert()
            }
        }
    }
    
    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage")
        let initialLanguage = savedLanguage ?? Self.detectSystemLanguage()
        self.currentLanguage = initialLanguage

        if savedLanguage == nil {
            print("First launch detected. Initialized language to: \(initialLanguage)")
        }
        
        // Ensure the language is set for the app bundle
        UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    private static func detectSystemLanguage() -> String {
        let systemLanguages = Locale.preferredLanguages
        
        // Check if Turkish is in preferred languages
        for language in systemLanguages {
            let languageCode = String(language.prefix(2))
            if languageCode == "tr" {
                return "tr"
            }
        }
        
        // Default to English if Turkish is not found
        return "en"
    }
    
    func localizedString(for key: String, defaultValue: String = "") -> String {
        // Get the appropriate bundle for the current language
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to main bundle if language bundle not found
            return NSLocalizedString(key, comment: defaultValue)
        }
        
        return bundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }
    
    private func showRestartAlert() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            let alert = UIAlertController(
                title: self.localizedString(for: "alert.language_changed_title", defaultValue: "Language Changed"),
                message: self.localizedString(for: "alert.language_changed_message", defaultValue: "Please restart the app to apply the language changes completely."),
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(
                title: self.localizedString(for: "action.restart_now", defaultValue: "Restart Now"),
                style: .default
            ) { _ in
                self.restartApp()
            })
            
            alert.addAction(UIAlertAction(
                title: self.localizedString(for: "action.restart_later", defaultValue: "Later"),
                style: .cancel
            ))
            
            if let topController = window.rootViewController {
                var currentController = topController
                while let presentedController = currentController.presentedViewController {
                    currentController = presentedController
                }
                currentController.present(alert, animated: true)
            }
        }
    }
    
    private func restartApp() {
        DispatchQueue.main.async {
            // Force app to exit and restart
            exit(0)
        }
    }
    
    // Available languages
    static let supportedLanguages = [
        Language(code: "en", name: "English"),
        Language(code: "tr", name: "Türkçe")
    ]
}

struct Language: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let name: String
}

// MARK: - String Extension for Easy Localization
extension String {
    var localized: String {
        return LanguageManager.shared.localizedString(for: self, defaultValue: self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

