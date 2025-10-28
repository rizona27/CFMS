import SwiftUI

struct CardModifier: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func cardStyle(backgroundColor: Color = .white, cornerRadius: CGFloat = 12) -> some View {
        self.modifier(CardModifier(backgroundColor: backgroundColor, cornerRadius: cornerRadius))
    }
}
