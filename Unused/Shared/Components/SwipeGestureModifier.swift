import SwiftUI

struct SwipeGestureModifier: ViewModifier {
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var showingActions = false
    
    private let actionWidth: CGFloat = 80
    private let threshold: CGFloat = 50
    
    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            if offset > 0 {
                leadingActionsView
            }
            
            content
                .offset(x: offset)
                .background(Color.systemBackground)
                .gesture(swipeGesture)
                .animation(CustomAnimations.smooth, value: offset)
            
            if offset < 0 {
                trailingActionsView
            }
        }
        .clipped()
        .onTapGesture {
            if showingActions {
                withAnimation {
                    resetOffset()
                }
            }
        }
    }
    
    private var leadingActionsView: some View {
        HStack(spacing: 0) {
            ForEach(Array(leadingActions.enumerated()), id: \.offset) { index, action in
                SwipeActionView(action: action) {
                    action.handler()
                    withAnimation {
                        resetOffset()
                    }
                }
                .frame(width: actionWidth)
            }
        }
        .frame(width: max(0, offset))
    }
    
    private var trailingActionsView: some View {
        HStack(spacing: 0) {
            ForEach(Array(trailingActions.enumerated()), id: \.offset) { index, action in
                SwipeActionView(action: action) {
                    action.handler()
                    withAnimation {
                        resetOffset()
                    }
                }
                .frame(width: actionWidth)
            }
        }
        .frame(width: max(0, -offset))
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                }
                
                let translation = value.translation.x
                let maxLeadingOffset = CGFloat(leadingActions.count) * actionWidth
                let maxTrailingOffset = -CGFloat(trailingActions.count) * actionWidth
                
                if translation > 0 && !leadingActions.isEmpty {
                    offset = min(translation, maxLeadingOffset)
                } else if translation < 0 && !trailingActions.isEmpty {
                    offset = max(translation, maxTrailingOffset)
                }
                
                showingActions = abs(offset) > threshold
            }
            .onEnded { value in
                isDragging = false
                
                let velocity = value.predictedEndLocation.x - value.location.x
                
                if abs(velocity) > 100 || abs(offset) > threshold {
                    // Snap to actions
                    let targetOffset: CGFloat
                    
                    if offset > 0 {
                        targetOffset = CGFloat(leadingActions.count) * actionWidth
                    } else {
                        targetOffset = -CGFloat(trailingActions.count) * actionWidth
                    }
                    
                    withAnimation(CustomAnimations.spring) {
                        offset = targetOffset
                        showingActions = true
                    }
                } else {
                    // Snap back to center
                    withAnimation(CustomAnimations.spring) {
                        resetOffset()
                    }
                }
            }
    }
    
    private func resetOffset() {
        offset = 0
        showingActions = false
    }
}

struct SwipeAction {
    let title: String
    let systemImage: String
    let backgroundColor: Color
    let foregroundColor: Color
    let handler: () -> Void
    
    init(
        title: String,
        systemImage: String,
        backgroundColor: Color,
        foregroundColor: Color = .white,
        handler: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.handler = handler
    }
}

struct SwipeActionView: View {
    let action: SwipeAction
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: action.systemImage)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(action.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(action.foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(action.backgroundColor)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(CustomAnimations.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) {
            // Long press completed
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

extension View {
    func swipeActions(
        leading: [SwipeAction] = [],
        trailing: [SwipeAction] = []
    ) -> some View {
        self.modifier(SwipeGestureModifier(
            leadingActions: leading,
            trailingActions: trailing
        ))
    }
}