import SwiftUI

struct AuthView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLogin = true
    @State private var isLoading = false
    @State private var message = ""
    @State private var messageColor: Color = .red
    
    // 密码可见性状态 - 分别为密码和确认密码设置独立状态
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    
    // 动画状态
    @State private var animationOffset: CGFloat = 100
    @State private var animationOpacity: Double = 0
    @State private var backgroundRotation: Double = 0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                backgroundGradient
                
                // 主要内容
                VStack(spacing: 0) {
                    headerSection
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            formSection
                            
                            actionButtons
                            
                            if !message.isEmpty {
                                messageSection
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            // 添加点击背景收起键盘的手势
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        ZStack {
            // 主背景
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
            
            // 动态光效
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "E8D5C4").opacity(0.2),
                                Color(hex: "F0ECE5").opacity(0.1),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 120 + CGFloat(index) * 40
                        )
                    )
                    .frame(
                        width: 200 + CGFloat(index) * 80,
                        height: 200 + CGFloat(index) * 80
                    )
                    .scaleEffect(1.0 - CGFloat(index) * 0.1)
                    .opacity(glowOpacity * (1.0 - Double(index) * 0.2))
                    .rotationEffect(.degrees(backgroundRotation * Double(index + 1) * 0.5))
                    .offset(x: CGFloat(index) * 30, y: CGFloat(index) * -20)
                    .blur(radius: 10 + CGFloat(index) * 3)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                backgroundRotation = 360
            }
            
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
            }
        }
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
            
            // 标题区域
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 8) {
                    Text("欢迎登录")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: "3E2723"))
                    
                    Text("登录您的账户继续使用")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(Color(hex: "6D4C41").opacity(0.8))
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            .opacity(animationOpacity)
            .offset(y: animationOffset)
        }
    }
    
    // MARK: - 表单区域
    private var formSection: some View {
        VStack(spacing: 16) {
            // 用户名输入
            inputCard(
                title: "用户名",
                systemImage: "person.fill",
                gradientColors: [Color(hex: "4facfe"), Color(hex: "00f2fe")],
                content: {
                    TextField("请输入用户名", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .onChange(of: username) { newValue in
                            validateUsername(newValue)
                        }
                }
            )
            
            // 密码输入
            inputCard(
                title: "密码",
                systemImage: "lock.fill",
                gradientColors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                content: {
                    HStack {
                        if showPassword {
                            TextField("请输入密码", text: $password)
                                .textContentType(isLogin ? .password : .newPassword)
                        } else {
                            SecureField("请输入密码", text: $password)
                                .textContentType(isLogin ? .password : .newPassword)
                        }
                        
                        // 密码显示/隐藏按钮 - 使用不同的图标
                        Button(action: {
                            showPassword.toggle()
                        }) {
                            Image(systemName: showPassword ? "eye.slash.circle.fill" : "eye.circle.fill")
                                .foregroundColor(showPassword ? .orange : .blue)
                                .font(.system(size: 20))
                        }
                    }
                    .onChange(of: password) { newValue in
                        validatePassword(newValue)
                    }
                }
            )
            
            // 确认密码（仅注册时显示）
            if !isLogin {
                inputCard(
                    title: "确认密码",
                    systemImage: "lock.rotation",
                    gradientColors: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                    content: {
                        HStack {
                            if showConfirmPassword {
                                TextField("请确认密码", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            } else {
                                SecureField("请确认密码", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            }
                            
                            // 确认密码显示/隐藏按钮 - 使用不同的图标
                            Button(action: {
                                showConfirmPassword.toggle()
                            }) {
                                Image(systemName: showConfirmPassword ? "eye.slash.square.fill" : "eye.square.fill")
                                    .foregroundColor(showConfirmPassword ? .purple : .green)
                                    .font(.system(size: 20))
                            }
                        }
                        .onChange(of: confirmPassword) { newValue in
                            validateConfirmPassword(newValue)
                        }
                    }
                )
            }
        }
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // 登录/注册按钮
            Button(action: {
                performAuth()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text(isLogin ? "登录中..." : "注册中...")
                            .fontWeight(.semibold)
                    } else {
                        Text(isLogin ? "登录" : "注册")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidForm ? AppTheme.accentGradient : LinearGradient(colors: [Color.gray, Color.gray.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: isValidForm ? .green.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!isValidForm || isLoading)
            
            // 切换模式按钮
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isLogin.toggle()
                    message = ""
                    confirmPassword = ""
                    showPassword = false
                    showConfirmPassword = false
                }
            }) {
                HStack {
                    Text(isLogin ? "没有账户？" : "已有账户？")
                        .foregroundColor(.secondary)
                    Text(isLogin ? "立即注册" : "立即登录")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primaryGradient)
                }
                .font(.system(size: 15))
            }
        }
        .padding(.top, 8)
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    // MARK: - 消息提示
    private var messageSection: some View {
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
    
    // MARK: - 输入卡片组件
    private func inputCard<Content: View>(
        title: String,
        systemImage: String,
        gradientColors: [Color],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    content()
                        .font(.system(size: 16))
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - 表单验证
    private var isValidForm: Bool {
        if username.isEmpty || password.isEmpty {
            return false
        }
        
        if !isLogin && confirmPassword.isEmpty {
            return false
        }
        
        // 用户名长度验证
        if username.count < 3 {
            return false
        }
        
        // 密码长度验证
        if password.count < 6 {
            return false
        }
        
        if !isLogin && password != confirmPassword {
            return false
        }
        
        return true
    }
    
    private func validateUsername(_ username: String) {
        // 简单的用户名验证
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 {
            // 不在UI中显示错误，只通过按钮状态控制
        }
    }
    
    private func validatePassword(_ password: String) {
        if password.count < 6 {
            // 不在UI中显示错误，只通过按钮状态控制
        }
    }
    
    private func validateConfirmPassword(_ confirmPassword: String) {
        if !isLogin && password != confirmPassword {
            // 不在UI中显示错误，只通过按钮状态控制
        }
    }
    
    // MARK: - 动画
    private func startAnimations() {
        animationOffset = 100
        animationOpacity = 0
        
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            animationOffset = 0
            animationOpacity = 1
        }
    }
    
    // MARK: - 认证操作
    private func performAuth() {
        isLoading = true
        message = ""
        
        // 隐藏键盘
        hideKeyboard()
        
        if isLogin {
            // 检查登录限制
            let loginCheck = authService.canLogin()
            if !loginCheck.canLogin {
                if let remainingTime = loginCheck.remainingTime {
                    let minutes = Int(ceil(remainingTime / 60))
                    messageColor = .red
                    message = "登录尝试次数过多，请\(minutes)分钟后再试"
                    isLoading = false
                    return
                }
            }
            
            authService.login(username: username, password: password) { success, msg in
                isLoading = false
                handleAuthResult(success: success, message: msg)
            }
        } else {
            // 检查注册限制
            let registerCheck = authService.canRegister()
            if !registerCheck.canRegister {
                if let remainingTime = registerCheck.remainingTime {
                    let minutes = Int(ceil(remainingTime / 60))
                    messageColor = .red
                    message = "注册过于频繁，请\(minutes)分钟后再试"
                    isLoading = false
                    return
                }
            }
            
            authService.register(username: username, password: password, confirmPassword: confirmPassword) { success, msg in
                isLoading = false
                handleAuthResult(success: success, message: msg)
            }
        }
    }
    
    private func handleAuthResult(success: Bool, message: String) {
        if success {
            messageColor = .green
            self.message = message
            // 登录/注册成功，延迟关闭页面
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            messageColor = .red
            self.message = message
        }
    }
    
    // MARK: - 收起键盘
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
