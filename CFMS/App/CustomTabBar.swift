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
            .padding(.top, 0)
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
                    // 未选中状态的圆形背景 - 作为阴影
                    if selectedTab != index {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .scaleEffect(pressingTab == index ? 0.85 : (animatingTab == index ? 0.9 : 1.0))
                    }
                    
                    // 选中状态的渐变圆形
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
                            .scaleEffect(pressingTab == index ? 1.15 : (animatingTab == index ? 1.1 : 1.0))
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 图标
                    Image(systemName: tabs[index].icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedTab == index ? .white : .gray)
                        .scaleEffect(pressingTab == index ? 1.4 : (animatingTab == index ? 1.5 : 1.0))
                        .rotationEffect(animatingTab == index ? .degrees(360) : .degrees(0))
                    
                    // 徽章
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
                
                // 标题
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
            // 点击当前选中的图标时触发放大动画
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.3)) {
                animatingTab = index
            }
            
            // 动画完成后重置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 10)) {
                    animatingTab = nil
                }
            }
        } else {
            // 切换标签时的平滑过渡动画
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.4)) {
                selectedTab = index
            }
        }
    }
    
    private func updateBadgeCounts() {
        // 在这里更新徽章计数
        // badgeCounts = [dataManager.unreadCount1, dataManager.unreadCount2, ...]
    }
}

struct EnhancedTabBarButtonStyle: ButtonStyle {
    @Binding var pressingTab: Int?
    let index: Int
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onChange(of: configuration.isPressed) { isPressed in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    pressingTab = isPressed ? index : nil
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
