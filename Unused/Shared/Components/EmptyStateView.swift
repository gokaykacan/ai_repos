import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let primaryButtonTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?
    
    init(
        systemImage: String,
        title: String,
        subtitle: String,
        primaryButtonTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryButtonTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.tertiaryLabel)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.label)
                    
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            
            VStack(spacing: 12) {
                if let primaryButtonTitle = primaryButtonTitle,
                   let primaryAction = primaryAction {
                    Button(action: primaryAction) {
                        Text(primaryButtonTitle)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                
                if let secondaryButtonTitle = secondaryButtonTitle,
                   let secondaryAction = secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryButtonTitle)
                            .font(.body)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondarySystemBackground)
                            .cornerRadius(12)
                    }
                }
            }
            .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView(
            systemImage: "checklist",
            title: "No Tasks",
            subtitle: "Tap the + button to create your first task and start organizing your day.",
            primaryButtonTitle: "Add Task",
            primaryAction: { print("Add task tapped") },
            secondaryButtonTitle: "Learn More",
            secondaryAction: { print("Learn more tapped") }
        )
        .previewLayout(.sizeThatFits)
        .frame(height: 400)
    }
}