// 自定义TabBar视图，用于App导航，包含选中状态管理、徽章计数和丰富的交互动画效果。
import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var dataManager: DataManager

    let tabs: [(icon: String, title: String, colors: [Color])] = [
        (icon: "chart.line.uptrend.xyaxis", title: "一览", colors: [Color(hex: "667eea"), Color(hex: "764ba2")]),
        (icon: "person.2", title: "客户", colors: [Color(hex: "f093fb"), Color(hex: "f5576c")]),
        (icon: "trophy", title: "排名", colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]),
        (icon: "gearshape", title: "设置", colors: [Color(hex: "43e97b"), Color(hex: "38f9d7")])
    ]

    @State private var badgeCounts = [0, 0, 0, 0]
    @State private var animatingTab: Int? = nil
    @State private var pressingTab: Int? = nil
    @State private var rotationAngles = [0.0, 0.0, 0.0, 0.0]

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    tabBarItem(for: index)
                }
            }
            .frame(height: 70)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .onAppear {
            updateBadgeCounts()
        }
    }

    private func tabBarItem(for index: Int) -> some View {
        Button(action: {
            handleTabSelection(index)
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab != index {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .scaleEffect(pressingTab == index ? 0.85 : (animatingTab == index ? 1.2 : 1.0))
                    }

                    if selectedTab == index {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: tabs[index].colors),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .shadow(
                                color: tabs[index].colors[0].opacity(0.3),
                                radius: 3,
                                x: 0,
                                y: 2
                            )
                            .scaleEffect(pressingTab == index ? 1.15 : (animatingTab == index ? 1.3 : 1.0))
                            .transition(.scale.combined(with: .opacity))
                    }

                    Image(systemName: tabs[index].icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedTab == index ? .white : .gray)
                        .scaleEffect(pressingTab == index ? 1.4 : (animatingTab == index ? 1.6 : 1.0))
                        .rotationEffect(.degrees(rotationAngles[index]))

                    if badgeCounts[index] > 0 {
                        Text("\(badgeCounts[index])")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                            .scaleEffect(animatingTab == index ? 1.2 : 1.0)
                    }
                }
                .frame(width: 28, height: 28)

                Text(tabs[index].title)
                    .font(.system(size: 10, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundColor(selectedTab == index ? tabs[index].colors[0] : .secondary)
                    .scaleEffect(animatingTab == index ? 1.1 : 1.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .padding(.vertical, 8)
        }
        .buttonStyle(EnhancedTabBarButtonStyle(pressingTab: $pressingTab, index: index))
    }

    private func handleTabSelection(_ index: Int) {
        if selectedTab == index {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.3)) {
                animatingTab = index
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 10)) {
                    animatingTab = nil
                }
            }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.4)) {
                rotationAngles[selectedTab] = 0
                selectedTab = index
                rotationAngles[index] = 360
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.2)) {
                    rotationAngles[index] = 0
                }
            }
        }
    }

    private func updateBadgeCounts() {
    }
}

struct EnhancedTabBarButtonStyle: ButtonStyle {
    @Binding var pressingTab: Int?
    let index: Int
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onChange(of: configuration.isPressed) { newValue in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    pressingTab = newValue ? index : nil
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
