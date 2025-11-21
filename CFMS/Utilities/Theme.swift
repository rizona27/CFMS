//主题定义模块
import SwiftUI

struct AppTheme {
    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "f093fb"), Color(hex: "f5576c")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let successGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "43e97b"), Color(hex: "38f9d7")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let orangeGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "fa709a"), Color(hex: "fee140")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let purpleGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "a8edea"), Color(hex: "fed6e3")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    static let themePrimary = Color(hex: "667eea")
    static let themeSecondary = Color(hex: "764ba2")
}
