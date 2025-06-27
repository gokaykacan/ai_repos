import SwiftUI

struct CustomAnimations {
    static let spring = Animation.interpolatingSpring(stiffness: 300, damping: 30)
    static let bouncy = Animation.interpolatingSpring(stiffness: 200, damping: 15)
    static let smooth = Animation.easeInOut(duration: 0.3)
    static let quick = Animation.easeInOut(duration: 0.15)
    static let slowFade = Animation.easeInOut(duration: 0.5)
}

struct SlideInModifier: ViewModifier {
    let direction: SlideDirection
    let delay: Double
    @State private var isVisible = false
    
    enum SlideDirection {
        case leading, trailing, top, bottom
    }
    
    func body(content: Content) -> some View {
        content
            .offset(
                x: isVisible ? 0 : offsetX,
                y: isVisible ? 0 : offsetY
            )
            .opacity(isVisible ? 1 : 0)
            .animation(CustomAnimations.spring.delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
    
    private var offsetX: CGFloat {
        switch direction {
        case .leading: return -100
        case .trailing: return 100
        default: return 0
        }
    }
    
    private var offsetY: CGFloat {
        switch direction {
        case .top: return -50
        case .bottom: return 50
        default: return 0
        }
    }
}

struct ScaleInModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            .animation(CustomAnimations.bouncy.delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

struct ShakeModifier: ViewModifier {
    let intensity: CGFloat
    let duration: Double
    @State private var shakeOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .animation(
                Animation.easeInOut(duration: 0.1)
                    .repeatCount(Int(duration * 10), autoreverses: true),
                value: shakeOffset
            )
    }
    
    func shake() {
        shakeOffset = intensity
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            shakeOffset = 0
        }
    }
}

struct PulseModifier: ViewModifier {
    let scale: CGFloat
    let duration: Double
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? scale : 1.0)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct FloatingActionButton: View {
    let systemImage: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.blue)
                        .shadow(
                            color: .blue.opacity(0.3),
                            radius: isPressed ? 8 : 12,
                            x: 0,
                            y: isPressed ? 4 : 8
                        )
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(CustomAnimations.quick, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) {
            // Long press completed
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(CustomAnimations.smooth, value: progress)
        }
        .frame(width: size, height: size)
    }
}

struct TaskCompletionAnimation: View {
    @State private var showCheckmark = false
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 50))
            .foregroundColor(.green)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(showCheckmark ? 1 : 0)
            .onAppear {
                withAnimation(CustomAnimations.bouncy) {
                    showCheckmark = true
                    scale = 1.0
                }
                
                withAnimation(CustomAnimations.spring.delay(0.1)) {
                    rotation = 360
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(CustomAnimations.smooth) {
                        showCheckmark = false
                        scale = 0.5
                    }
                }
            }
    }
}

extension View {
    func slideIn(
        from direction: SlideInModifier.SlideDirection,
        delay: Double = 0
    ) -> some View {
        self.modifier(SlideInModifier(direction: direction, delay: delay))
    }
    
    func scaleIn(delay: Double = 0) -> some View {
        self.modifier(ScaleInModifier(delay: delay))
    }
    
    func shake(intensity: CGFloat = 10, duration: Double = 0.5) -> some View {
        self.modifier(ShakeModifier(intensity: intensity, duration: duration))
    }
    
    func pulse(scale: CGFloat = 1.1, duration: Double = 1.0) -> some View {
        self.modifier(PulseModifier(scale: scale, duration: duration))
    }
}