import SwiftUI

struct PriorityIndicatorView: View {
    let priority: TaskPriority

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(gradient: Gradient(colors: [priority.color.opacity(0.7), priority.color]), startPoint: .leading, endPoint: .trailing))
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: priority.systemImage)
                    .font(.caption2)
                    .foregroundColor(.white)
            )
    }
}

struct PriorityIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            PriorityIndicatorView(priority: .low) 
            PriorityIndicatorView(priority: .medium)
            PriorityIndicatorView(priority: .high)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}