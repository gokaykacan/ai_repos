import SwiftUI

struct AnimatedCheckbox: View {
    @Binding var isChecked: Bool

    var body: some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundColor(isChecked ? .green : .gray)
            .scaleEffect(isChecked ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isChecked)
            .onTapGesture {
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