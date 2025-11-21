import SwiftUI

struct RedemptionView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var redemptionCode = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var messageColor: Color = .red
    @State private var showSuccessAnimation = false
    
    // 动画状态
    @State private var animationOffset: CGFloat = 50
    @State private var animationOpacity: Double = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "F8F5F0"),
                                Color(hex: "F0ECE5"),
                                Color(hex: "F8F5F0")
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 头部
                    headerSection
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // 图标和标题
                            VStack(spacing: 16) {
                                Image(systemName: "gift.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(AppTheme.primaryGradient)
                                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                VStack(spacing: 8) {
                                    Text("VIP权益兑换")
                                        .font(.system(size: 28, weight: .bold, design: .serif))
                                        .foregroundColor(Color(hex: "3E2723"))
                                    
                                    Text("输入兑换码解锁高级功能")
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(Color(hex: "6D4C41").opacity(0.8))
                                }
                            }
                            .opacity(animationOpacity)
                            .offset(y: animationOffset)
                            
                            // 输入框
                            VStack(alignment: .leading, spacing: 12) {
                                Text("兑换码")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.purple)
                                    
                                    TextField("请输入兑换码", text: $redemptionCode)
                                        .textInputAutocapitalization(.characters)
                                        .disableAutocorrection(true)
                                        .padding(.vertical, 12)
                                }
                                .padding(.horizontal, 16)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                            }
                            .opacity(animationOpacity)
                            .offset(y: animationOffset)
                            
                            // 兑换按钮
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
                            
                            // 消息提示
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
                            
                            // VIP特权说明
                            VStack(alignment: .leading, spacing: 16) {
                                Text("VIP特权")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                ForEach(vipFeatures, id: \.self) { feature in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                        
                                        Text(feature)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                            .opacity(animationOpacity)
                            .offset(y: animationOffset)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
                
                // 成功动画
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
    
    // MARK: - 头部区域
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                        
                        Image(systemName: "chevron.backward.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                    .frame(width: 32, height: 32)
                }
                
                Spacer()
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.systemGroupedBackground).opacity(0.8))
        }
    }
    
    // MARK: - VIP特权列表
    private var vipFeatures: [String] {
        [
            "无限次数据刷新",
            "高级数据分析功能",
            "专属客户支持",
            "数据导出无限制",
            "优先体验新功能"
        ]
    }
    
    // MARK: - 动画
    private func startAnimations() {
        animationOffset = 50
        animationOpacity = 0
        
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            animationOffset = 0
            animationOpacity = 1
        }
    }
    
    // MARK: - 兑换逻辑
    private func redeemCode() {
        isLoading = true
        message = ""
        
        // 隐藏键盘
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // 验证兑换码格式
        guard !redemptionCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            messageColor = .red
            message = "兑换码不能为空"
            isLoading = false
            return
        }
        
        // 调用后端API验证兑换码
        validateRedemptionCode()
    }
    
    // MARK: - 验证兑换码API调用
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
        
        // 添加认证token
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
                            // 兑换码有效，进行兑换
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
    
    // MARK: - 兑换API调用
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
        
        // 添加认证token
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
                            // 兑换成功
                            self.messageColor = .green
                            self.message = json["message"] as? String ?? "兑换成功"
                            
                            // 更新用户信息
                            if let userInfo = json["user_info"] as? [String: Any] {
                                self.updateUserInfo(userInfo)
                            }
                            
                            // 显示成功动画
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
    
    // MARK: - 更新用户信息
    private func updateUserInfo(_ userInfo: [String: Any]) {
        // 更新AuthService中的用户信息
        if var currentUser = authService.currentUser {
            // 更新用户类型
            if let userType = userInfo["user_type"] as? String {
                // 由于User是值类型，我们需要创建一个新的User实例
                let updatedUser = User(
                    id: currentUser.id,
                    username: currentUser.username,
                    userType: userType,
                    subscriptionStart: (userInfo["subscription_start"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) },
                    subscriptionEnd: (userInfo["subscription_end"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
                )
                
                authService.currentUser = updatedUser
                
                // 保存到UserDefaults
                if let userData = try? JSONSerialization.data(withJSONObject: userInfo) {
                    UserDefaults.standard.set(userData, forKey: "userData")
                }
                
                // 发送通知更新界面
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserInfoUpdated"),
                    object: nil
                )
            }
        }
    }
}

// MARK: - 成功动画视图
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
