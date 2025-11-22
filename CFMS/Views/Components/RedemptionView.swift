//权益兑换页面
import SwiftUI
struct RedemptionView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var redemptionCode = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var messageColor: Color = .red
    @State private var showSuccessAnimation = false

    @State private var animationOffset: CGFloat = 50
    @State private var animationOpacity: Double = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: backgroundColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    headerSection
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            VStack(spacing: 16) {
                                Image(systemName: "gift.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(AppTheme.primaryGradient)
                                    .shadow(color: .purple.opacity(colorScheme == .dark ? 0.2 : 0.3), radius: 8, x: 0, y: 4)
                                
                                VStack(spacing: 8) {
                                    Text("尊享权益兑换")
                                        .font(.system(size: 28, weight: .bold, design: .serif))
                                        .foregroundColor(primaryTextColor)
                                    
                                    Text("输入兑换码解锁高级功能")
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(subtitleColor)
                                }
                            }
                            .opacity(animationOpacity)
                            .offset(y: animationOffset)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("兑换码")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(primaryTextColor)
                                
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.purple)
                                    
                                    TextField("请输入兑换码", text: $redemptionCode)
                                        .textInputAutocapitalization(.characters)
                                        .disableAutocorrection(true)
                                        .padding(.vertical, 12)
                                        .foregroundColor(primaryTextColor)
                                }
                                .padding(.horizontal, 16)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
                            }
                            .opacity(animationOpacity)
                            .offset(y: animationOffset)

                            Button(action: {
                                redeemCode()
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("兑换中...")
                                            .fontWeight(.semibold)
                                    } else {
                                        Text("立即兑换")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(!redemptionCode.isEmpty ? AppTheme.accentGradient : LinearGradient(colors: [Color.gray, Color.gray.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: !redemptionCode.isEmpty ? .green.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                            }
                            .disabled(redemptionCode.isEmpty || isLoading)
                            .opacity(animationOpacity)
                            .offset(y: animationOffset)

                            if !message.isEmpty {
                                HStack {
                                    Image(systemName: messageColor == .green ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    Text(message)
                                }
                                .foregroundColor(messageColor)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(messageColor.opacity(0.1))
                                .cornerRadius(8)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }

                            VStack(alignment: .leading, spacing: 16) {
                                Text("尊享特权")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(primaryTextColor)
                                
                                ForEach(vipFeatures, id: \.self) { feature in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                        
                                        Text(feature)
                                            .font(.system(size: 14))
                                            .foregroundColor(secondaryTextColor)
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
                            .opacity(animationOpacity)
                            .offset(y: animationOffset)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }

                if showSuccessAnimation {
                    SuccessAnimationView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                showSuccessAnimation = false
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                startAnimations()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: "1A1A2E"),
                Color(hex: "16213E"),
                Color(hex: "0F3460")
            ]
        } else {
            return [
                Color(hex: "F8F5F0"),
                Color(hex: "F0ECE5"),
                Color(hex: "F8F5F0")
            ]
        }
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "3E2723")
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(hex: "6D4C41").opacity(0.8)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .secondary
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Spacer()
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                colorScheme == .dark ?
                Color(.systemBackground).opacity(0.4) :
                Color(.systemGroupedBackground).opacity(0.8)
            )
        }
    }

    private var vipFeatures: [String] {
        [
            "收益报告查看、导出",
            "数据库备份、下载",
            "解锁用户、产品上限",
            "优先体验其他新功能"
        ]
    }

    private func startAnimations() {
        animationOffset = 50
        animationOpacity = 0
        
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            animationOffset = 0
            animationOpacity = 1
        }
    }

    private func redeemCode() {
        isLoading = true
        message = ""

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        guard !redemptionCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            messageColor = .red
            message = "兑换码不能为空"
            isLoading = false
            return
        }

        validateRedemptionCode()
    }

    private func validateRedemptionCode() {
        guard let url = URL(string: "\(authService.baseURL)/api/validate_redemption_code") else {
            messageColor = .red
            message = "服务器连接失败"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authService.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "redemption_code": redemptionCode.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            messageColor = .red
            message = "请求数据错误"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.messageColor = .red
                    self.message = "网络错误: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let data = data else {
                    self.messageColor = .red
                    self.message = "没有收到服务器响应"
                    self.isLoading = false
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            self.redeemCodeAPI()
                        } else {
                            let errorMessage = json["error"] as? String ?? "兑换码无效"
                            self.messageColor = .red
                            self.message = errorMessage
                            self.isLoading = false
                        }
                    } else {
                        self.messageColor = .red
                        self.message = "响应格式错误"
                        self.isLoading = false
                    }
                } catch {
                    self.messageColor = .red
                    self.message = "数据解析错误"
                    self.isLoading = false
                }
            }
        }.resume()
    }

    private func redeemCodeAPI() {
        guard let url = URL(string: "\(authService.baseURL)/api/redeem_code") else {
            messageColor = .red
            message = "服务器连接失败"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authService.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "redemption_code": redemptionCode.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            messageColor = .red
            message = "请求数据错误"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.messageColor = .red
                    self.message = "网络错误: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.messageColor = .red
                    self.message = "没有收到服务器响应"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            self.messageColor = .green
                            self.message = json["message"] as? String ?? "兑换成功"
                            
                            if let userInfo = json["user_info"] as? [String: Any] {
                                self.updateUserInfo(userInfo)
                            }

                            self.showSuccessAnimation = true
                            
                        } else {
                            let errorMessage = json["error"] as? String ?? "兑换失败"
                            self.messageColor = .red
                            self.message = errorMessage
                        }
                    } else {
                        self.messageColor = .red
                        self.message = "响应格式错误"
                    }
                } catch {
                    self.messageColor = .red
                    self.message = "数据解析错误: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private func updateUserInfo(_ userInfo: [String: Any]) {
        print("🔧 开始更新用户信息: \(userInfo)")

        if let currentUser = authService.currentUser {
            if let userTypeString = userInfo["user_type"] as? String,
               let userType = AuthService.UserType(rawValue: userTypeString) {

                let subscriptionStart = parseDate(from: userInfo["subscription_start"] as? String)
                let subscriptionEnd = parseDate(from: userInfo["subscription_end"] as? String)
                
                print("🔧 更新用户信息 - 类型: \(userType), 开始: \(subscriptionStart?.description ?? "nil"), 结束: \(subscriptionEnd?.description ?? "nil")")

                let updatedUser = User(
                    id: currentUser.id,
                    username: currentUser.username,
                    userType: userType,
                    subscriptionStart: subscriptionStart,
                    subscriptionEnd: subscriptionEnd
                )

                authService.currentUser = updatedUser

                var completeUserData: [String: Any] = [
                    "user_id": Int(currentUser.id) ?? 0,
                    "username": currentUser.username,
                    "user_type": userType.rawValue,
                    "has_full_access": userType == .vip || userType == .subscribed,
                    "email": ""
                ]

                if let subscriptionStart = subscriptionStart {
                    let formatter = ISO8601DateFormatter()
                    completeUserData["subscription_start"] = formatter.string(from: subscriptionStart)
                }
                
                if let subscriptionEnd = subscriptionEnd {
                    let formatter = ISO8601DateFormatter()
                    completeUserData["subscription_end"] = formatter.string(from: subscriptionEnd)
                }

                if let userJsonData = try? JSONSerialization.data(withJSONObject: completeUserData) {
                    UserDefaults.standard.set(userJsonData, forKey: "userData")
                    print("🔧 用户信息已保存到UserDefaults")
                }

                NotificationCenter.default.post(
                    name: NSNotification.Name("UserInfoUpdated"),
                    object: nil
                )
                
                authService.objectWillChange.send()
            }
        }
    }
    
    private func parseDate(from string: String?) -> Date? {
        guard let string = string else { return nil }
        
        let formatters = [
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return formatter
            }(),
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        print("🔧 无法解析日期字符串: \(string)")
        return nil
    }
}

struct SuccessAnimationView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 120, height: 120)
                        .scaleEffect(scale)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                }
                
                Text("兑换成功!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.linear(duration: 0.5).delay(0.2)) {
                rotation = 360
            }
        }
    }
}
