import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var dataManager: DataManager
    
    let tabs = [
        (icon: "chart.line.uptrend.xyaxis", title: "一览", colors: [Color(hex: "667eea"), Color(hex: "764ba2")]),
        (icon: "person.2", title: "客户", colors: [Color(hex: "f093fb"), Color(hex: "f5576c")]),
        (icon: "trophy", title: "排名", colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]),
        (icon: "gearshape", title: "设置", colors: [Color(hex: "43e97b"), Color(hex: "38f9d7")])
    ]
    
    // 徽章计数状态
    @State private var badgeCounts = [0, 0, 0, 0]
    
    var body: some View {
        VStack(spacing: 0) {
            // 添加一个细分割线
            Divider()
                .background(Color.gray.opacity(0.2))
            
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = index
                        }
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                // 未选中状态的灰色背景
                                if selectedTab != index {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 28, height: 28)
                                        .opacity(0.8)
                                }
                                
                                // 渐变背景（选中状态）
                                if selectedTab == index {
                                    LinearGradient(
                                        gradient: Gradient(colors: tabs[index].colors),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .shadow(color: tabs[index].colors[0].opacity(0.4), radius: 3, x: 0, y: 2)
                                }
                                
                                Image(systemName: tabs[index].icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedTab == index ? .white : .gray)
                                    .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                                
                                // 徽章（可选）
                                if badgeCounts[index] > 0 {
                                    Text("\(badgeCounts[index])")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(minWidth: 14, minHeight: 14)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 10, y: -10)
                                }
                            }
                            .frame(width: 28, height: 28)
                            
                            Text(tabs[index].title)
                                .font(.system(size: 10, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundColor(selectedTab == index ? tabs[index].colors[0] : .secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TabBarButtonStyle())
                }
            }
            .frame(height: 60) // 固定高度，适合底部导航栏
            .padding(.horizontal, 8)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .onAppear {
            // 可以在这里初始化徽章数据
            updateBadgeCounts()
        }
    }
    
    private func updateBadgeCounts() {
        // 这里可以添加更新徽章计数的逻辑
        // 例如：badgeCounts[0] = dataManager.outdatedFundsCount
    }
}

// 修复：使用 some View 而不是 View
struct TabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// 预览
struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        CustomTabBar(selectedTab: .constant(0))
            .environmentObject(DataManager())
            .previewLayout(.sizeThatFits)
    }
}
