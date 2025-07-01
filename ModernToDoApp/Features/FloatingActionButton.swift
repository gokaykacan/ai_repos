import SwiftUI

struct FloatingActionButton: View {
    @State private var isExpanded = false
    let mainAction: () -> Void
    let subActions: [(imageName: String, action: () -> Void, label: String)]

    var body: some View {
        VStack {
            if isExpanded {
                ForEach(subActions.indices.reversed(), id: \.self) { index in
                    HStack {
                        Text(subActions[index].label)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.8)))
                            .shadow(radius: 2)
                        Button(action: {
                            subActions[index].action()
                            isExpanded = false // Collapse after action
                        }) {
                            Image(systemName: subActions[index].imageName)
                                .font(.title2)
                                .padding(12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            Button(action: {
                withAnimation(.spring()) {
                    if isExpanded { // If currently expanded, collapse
                        isExpanded = false
                    } else { // If currently collapsed, expand or perform main action
                        if subActions.isEmpty { // If no sub-actions, perform main action directly
                            mainAction()
                        } else { // If sub-actions exist, expand
                            isExpanded = true
                        }
                    }
                }
            }) {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.title2)
                    .padding(10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 5)
            }
        }
        .padding()
    }
}

struct FloatingActionButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.gray.opacity(0.1).ignoresSafeArea()
            FloatingActionButton(mainAction: { print("Main action tapped") }, subActions: [
                (imageName: "doc.badge.plus", action: { print("Add Task") }, label: "fab.add_task".localized),
                (imageName: "folder.badge.plus", action: { print("Add Category") }, label: "fab.add_category".localized)
            ])
        }
    }
}