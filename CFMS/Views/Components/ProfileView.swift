import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showAuthView = false
    @State private var showRedemptionView = false
    
    var body: some View {
        NavigationView {
            List {
                if authService.isLoggedIn, let user = authService.currentUser {
                    // 已登录的用户信息部分
                    Section(header: Text("用户信息")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.headline)
                                Text(getUserTypeText(user.userType))
                                    .font(.subheadline)
                                    .foregroundColor(getUserTypeColor(user.userType))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // VIP升级部分
                    Section(header: Text("VIP升级")) {
                        if user.userType == "free" {
                            Text("当前为免费用户")
                            Button("兑换VIP") {
                                showRedemptionView = true
                            }
                            .foregroundColor(.blue)
                        } else if user.userType == "subscribed", let endDate = user.subscriptionEnd {
                            Text("试用VIP，有效期至: \(formatDate(endDate))")
                        } else if user.userType == "vip" {
                            Text("永久VIP用户")
                                .foregroundColor(.green)
                        }
                    }
                    
                    // 退出登录
                    Section {
                        Button("退出登录") {
                            authService.logout()
                        }
                        .foregroundColor(.red)
                    }
                    
                } else {
                    // 未登录状态
                    Section {
                        Button("登录 / 注册") {
                            showAuthView = true
                        }
                        .foregroundColor(.blue)
                    } header: {
                        Text("账户")
                    } footer: {
                        Text("登录后享受更多功能")
                    }
                }
            }
            .navigationTitle("个人中心")
            .sheet(isPresented: $showAuthView) {
                AuthView()
            }
            .sheet(isPresented: $showRedemptionView) {
                RedemptionView()
            }
        }
    }
    
    private func getUserTypeText(_ userType: String) -> String {
        switch userType {
        case "free": return "免费用户"
        case "subscribed": return "试用VIP"
        case "vip": return "永久VIP"
        default: return "未知用户"
        }
    }
    
    private func getUserTypeColor(_ userType: String) -> Color {
        switch userType {
        case "free": return .gray
        case "subscribed": return .orange
        case "vip": return .green
        default: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}
