import SwiftUI
import UIKit

struct AnimatedCheckbox: View {
    @Binding var isChecked: Bool

    var body: some View {
        ZStack {
            // Modern circular design with gradient
            Circle()
                .fill(
                    isChecked ? 
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(isChecked ? Color.green : Color.gray.opacity(0.4), lineWidth: 2.5)
                )
                .shadow(color: isChecked ? Color.green.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isChecked ? 1.1 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isChecked)
        .onTapGesture {
            // Add haptic feedback for better user experience
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Toggle without wrapping in withAnimation to preserve binding functionality
            isChecked.toggle()
        }
    }
}

struct AnimatedCheckbox_Previews: PreviewProvider {
    @State static var isCheckedPreview = false
    static var previews: some View {
        AnimatedCheckbox(isChecked: $isCheckedPreview)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}