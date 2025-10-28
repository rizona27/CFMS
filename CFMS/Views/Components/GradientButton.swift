import SwiftUI

struct GradientButton: View {
    let icon: String
    let action: () -> Void
    var colors: [Color] = [.blue, .purple]
    var size: CGFloat = 32
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: colors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: colors.first?.opacity(0.3) ?? .gray.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
}
