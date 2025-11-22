// 在 GradientButton.swift 文件中添加

// 定义了一个名为 GradientButton 的 View 组件，其核心作用是创建一个具有视觉吸引力的、圆形图标按钮。
import SwiftUI

struct GradientButton: View {
    let icon: String
    let action: () -> Void
    var colors: [Color] = [.blue, .purple]
    var size: CGFloat = 32
    var iconSize: CGFloat = 18  // 将字体大小改为变量
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
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

// 新增：统一的返回按钮组件
struct BackButton: View {
    let action: () -> Void
    var colors: [Color] = [Color(hex: "4facfe"), Color(hex: "00f2fe")] // 使用统一的蓝绿色渐变
    
    var body: some View {
        GradientButton(
            icon: "chevron.backward.circle",
            action: action,
            colors: colors,
            size: 32,
            iconSize: 20  // 返回按钮图标稍大
        )
    }
}

// 如果需要在某些页面使用主题渐变，可以添加这个变体
struct ThemedBackButton: View {
    let action: () -> Void
    
    var body: some View {
        GradientButton(
            icon: "chevron.backward.circle",
            action: action,
            colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")], // 或者使用您 AppTheme 中的颜色
            size: 32,
            iconSize: 20
        )
    }
}
