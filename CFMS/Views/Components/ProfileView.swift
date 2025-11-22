//用户中心页面
import SwiftUI
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showAuthView = false
    @State private var showRedemptionView = false
    @State private var userProfile: UserProfile?
    
    struct UserProfile: Codable {
        let username: String
        let email: String?
        let userType: String
        let subscriptionStart: String?
        let subscriptionEnd: String?
        let createdAt: String?
        let lastLogin: String?
        let hasFullAccess: Bool
        let permissionMessage: String?
    }
    
    var body: some View {
        NavigationView {
            List {
                if authService.isLoggedIn, let user = authService.currentUser {
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
                                
                                if let profile = userProfile {
                                    if user.userType == .subscribed, let endDate = profile.subscriptionEnd {
                                        Text("有效期至: \(formatDateString(endDate))")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else if user.userType == .vip {
                                        Text("永久有效")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("VIP升级")) {
                        if user.userType == .free {
                            Text("当前为免费用户")
                            Button("兑换VIP") {
                                showRedemptionView = true
                            }
                            .foregroundColor(.blue)
                        } else if user.userType == .subscribed, let profile = userProfile, let endDate = profile.subscriptionEnd {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("试用VIP")
                                Text("有效期至: \(formatDateString(endDate))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        } else if user.userType == .vip {
                            Text("永久VIP用户")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Section {
                        Button("退出登录") {
                            authService.logout()
                        }
                        .foregroundColor(.red)
                    }
                    
                } else {
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
            .onAppear {
                if authService.isLoggedIn {
                    fetchUserProfile()
                }
            }
            .refreshable {
                if authService.isLoggedIn {
                    fetchUserProfile()
                }
            }
        }
    }
    
    private func fetchUserProfile() {
        guard let token = authService.authToken else { return }
        
        let url = URL(string: "\(authService.baseURL)/api/profile")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(ProfileResponse.self, from: data)
                    if response.success, let userData = response.user {
                        DispatchQueue.main.async {
                            self.userProfile = userData
                        }
                    }
                } catch {
                    print("解析用户资料失败: \(error)")
                }
            }
        }.resume()
    }
    
    private struct ProfileResponse: Codable {
        let success: Bool
        let user: UserProfile?
    }
    
    private func getUserTypeText(_ userType: AuthService.UserType) -> String {
        switch userType {
        case .free: return "基础用户"
        case .subscribed: return "体验用户"
        case .vip: return "尊享用户"
        }
    }
    
    private func getUserTypeColor(_ userType: AuthService.UserType) -> Color {
        switch userType {
        case .free: return .gray
        case .subscribed: return .orange
        case .vip: return .green
        }
    }
    
    private func formatDateString(_ dateString: String) -> String {
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .none
        outputFormatter.locale = Locale(identifier: "zh_CN")
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd"
        if let date = fallbackFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        return dateString
    }
}
