//定义了一个名为 GradientButton 的 View 组件，其核心作用是创建一个具有视觉吸引力的、圆形图标按钮。
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
