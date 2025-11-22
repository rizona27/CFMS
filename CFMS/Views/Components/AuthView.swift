//登录页模块
import SwiftUI
struct AuthView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var captcha = ""
    @State private var isLogin = true
    @State private var isLoading = false
    @State private var message = ""
    @State private var messageColor: Color = .red
    @State private var showPassword = false
    @State private var rememberUsername = false
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme

    @State private var animationOffset: CGFloat = 100
    @State private var animationOpacity: Double = 0
    @State private var backgroundRotation: Double = 0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerSection
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            formSection
                            
                            if authService.requiresCaptcha() {
                                captchaSection
                            }
                            
                            rememberUsernameSection
                            
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
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            startAnimations()
            loadRememberedUsername()
            // 如果需要验证码，进入页面时预加载
            if authService.requiresCaptcha() {
                authService.fetchCaptcha()
            }
        }
    }

    private var backgroundGradient: some View {
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

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: circleGradientColors),
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
                glowOpacity = colorScheme == .dark ? 0.2 : 0.6
            }
        }
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

    private var circleGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: "2D4263").opacity(0.3),
                Color(hex: "16213E").opacity(0.2),
                Color.clear
            ]
        } else {
            return [
                Color(hex: "E8D5C4").opacity(0.2),
                Color(hex: "F0ECE5").opacity(0.1),
                Color.clear
            ]
        }
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
                Color(.systemGroupedBackground).opacity(0.6)
            )

            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .shadow(color: .blue.opacity(colorScheme == .dark ? 0.2 : 0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 8) {
                    Text("欢迎登录")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "3E2723"))
                    
                    Text("登录您的账户继续使用")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(
                            colorScheme == .dark ?
                            Color.white.opacity(0.7) :
                            Color(hex: "6D4C41").opacity(0.8)
                        )
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            .opacity(animationOpacity)
            .offset(y: animationOffset)
        }
    }

    private var formSection: some View {
        VStack(spacing: 16) {
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

            if !isLogin {
                inputCard(
                    title: "确认密码",
                    systemImage: "lock.rotation",
                    gradientColors: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                    content: {
                        HStack {
                            if showPassword {
                                TextField("请确认密码", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            } else {
                                SecureField("请确认密码", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            }

                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash.circle.fill" : "eye.circle.fill")
                                    .foregroundColor(showPassword ? .orange : .blue)
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
    
    private var captchaSection: some View {
        inputCard(
            title: "验证码",
            systemImage: "shield.lefthalf.filled",
            gradientColors: [Color(hex: "ff9a9e"), Color(hex: "fecfef")],
            content: {
                HStack {
                    TextField("请输入验证码", text: $captcha)
                        .textContentType(.oneTimeCode)
                    
                    Button(action: {
                        // 点击图片刷新验证码
                        authService.fetchCaptcha()
                        captcha = ""
                    }) {
                        if let image = authService.captchaImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 34)
                                .cornerRadius(4)
                        } else {
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                                Text("加载中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 100, height: 34)
                            .onAppear {
                                // 如果图片为空，自动加载
                                authService.fetchCaptcha()
                            }
                        }
                    }
                }
            }
        )
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    private var rememberUsernameSection: some View {
        HStack {
            Button(action: {
                rememberUsername.toggle()
                authService.setRememberUsername(rememberUsername)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: rememberUsername ? "checkmark.square.fill" : "square")
                        .foregroundColor(rememberUsername ? .blue : .gray)
                    Text("记住用户名")
                        .font(.system(size: 14))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
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

            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isLogin.toggle()
                    message = ""
                    confirmPassword = ""
                    captcha = ""
                    showPassword = false
                }
            }) {
                HStack {
                    Text(isLogin ? "没有账户？" : "已有账户？")
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .secondary)
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
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
        }
    }

    private var isValidForm: Bool {
        if username.isEmpty || password.isEmpty {
            return false
        }
        
        if !isLogin && confirmPassword.isEmpty {
            return false
        }

        if authService.requiresCaptcha() && captcha.isEmpty {
            return false
        }

        if username.count < 3 {
            return false
        }

        if password.count < 6 {
            return false
        }
        
        if !isLogin && password != confirmPassword {
            return false
        }
        
        return true
    }
    
    private func validateUsername(_ username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 {
        }
    }
    
    private func validatePassword(_ password: String) {
        if password.count < 6 {
        }
    }
    
    private func validateConfirmPassword(_ confirmPassword: String) {
        if !isLogin && password != confirmPassword {
        }
    }
    
    private func loadRememberedUsername() {
        rememberUsername = authService.shouldRememberUsername()
        if rememberUsername {
            username = authService.getLastUsername()
        }
    }

    private func startAnimations() {
        animationOffset = 100
        animationOpacity = 0
        
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            animationOffset = 0
            animationOpacity = 1
        }
    }

    private func performAuth() {
        isLoading = true
        message = ""
        
        hideKeyboard()
        
        if isLogin {
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

            if authService.requiresCaptcha() {
                // 前端已经通过绑定 authService.captchaId 获取了ID
                // 这里的 captcha 变量是 Textfield 绑定的字符串
                authService.login(username: username, password: password, captcha: captcha) { success, msg in
                    isLoading = false
                    handleAuthResult(success: success, message: msg)
                }
            } else {
                authService.login(username: username, password: password) { success, msg in
                    isLoading = false
                    handleAuthResult(success: success, message: msg)
                }
            }
        } else {
            let authCheck = authService.canAuth()
            if !authCheck.canAuth {
                if let remainingTime = authCheck.remainingTime {
                    let minutes = Int(ceil(remainingTime / 60))
                    messageColor = .red
                    message = "认证尝试次数过多，请\(minutes)分钟后再试"
                    isLoading = false
                    return
                }
            }
            
            let registerCheck = authService.canRegister()
            if !registerCheck.canRegister {
                if let remainingTime = registerCheck.remainingTime {
                    let hours = Int(ceil(remainingTime / 3600))
                    if hours > 0 {
                        messageColor = .red
                        message = "注册过于频繁，请\(hours)小时后再试"
                    } else {
                        let minutes = Int(ceil(remainingTime / 60))
                        messageColor = .red
                        message = "注册过于频繁，请\(minutes)分钟后再试"
                    }
                    isLoading = false
                    return
                } else {
                    messageColor = .red
                    message = "当前设备注册账户数量已达上限"
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            messageColor = .red
            self.message = message
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
