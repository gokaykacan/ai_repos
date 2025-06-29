import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: UInt32 = (UInt32(red * 255) << 16) | (UInt32(green * 255) << 8) | UInt32(blue * 255)
        
        return String(format: "#%06X", rgb) // Use %06X for RGB only
    }
}

// MARK: - UIApplication Extension for Keyboard Dismissal
extension UIApplication {
    /// Dismisses the keyboard by sending the resignFirstResponder action
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - SwiftUI View Extensions for Keyboard Dismissal
extension View {
    /// Adds a tap gesture to dismiss the keyboard when tapping outside text fields
    /// - Returns: Modified view with keyboard dismissal capability
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.dismissKeyboard()
        }
    }
    
    /// Advanced keyboard dismissal with additional options
    /// - Parameters:
    ///   - includesSafeArea: Whether to include safe area in tap detection
    /// - Returns: Modified view with advanced keyboard dismissal
    func dismissKeyboardOnTapAdvanced(includesSafeArea: Bool = true) -> some View {
        ZStack {
            // Invisible background that captures taps
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.dismissKeyboard()
                }
                .ignoresSafeArea(includesSafeArea ? .all : [])
            
            self
        }
    }
    
    /// Optimized keyboard dismissal for forms
    /// - Returns: Modified view with form-optimized keyboard dismissal
    func dismissKeyboardOnFormTap() -> some View {
        background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.dismissKeyboard()
                }
        )
    }
    
    /// Keyboard dismissal that works safely with lists and other interactive elements
    /// - Returns: Modified view with list-safe keyboard dismissal
    func dismissKeyboardSafely() -> some View {
        simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.dismissKeyboard()
                }
        )
    }
}