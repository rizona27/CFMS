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
    
    @State private var showBiometricOption = false
    @State private var isBiometricLoading = false
    @State private var showBiometricAlert = false
    @State private var biometricAlertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerSection
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            formSection
                            
                            // 生物识别登录按钮
                            if showBiometricOption && !isLoading {
                                biometricLoginSection
                            }
                            
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
            checkBiometricAvailability()
            // 如果需要验证码，进入页面时预加载
            if authService.requiresCaptcha() {
                authService.fetchCaptcha()
            }
        }
        .alert("启用\(authService.biometricType)登录", isPresented: $showBiometricAlert) {
            Button("启用") {
                if authService.saveBiometricCredentials(username: username, password: password) {
                    print("生物识别登录已启用")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            Button("暂不", role: .cancel) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text(biometricAlertMessage)
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

            HStack(alignment: .center, spacing: 8) {
                Text("欢迎来到")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(
                        colorScheme == .dark ?
                        Color.white.opacity(0.9) :
                        Color(hex: "3E2723")
                    )
                    .shadow(
                        color: colorScheme == .dark ?
                            Color.black.opacity(0.3) :
                            Color.gray.opacity(0.2),
                        radius: 2, x: 1, y: 1
                    )
                
                Text("☆")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "FFD700"),
                                Color(hex: "FFA500"),
                                Color(hex: "FF8C00")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: Color(hex: "FFD700").opacity(0.4),
                        radius: 4, x: 0, y: 0
                    )
                    .overlay(
                        Text("☆")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "FFD700").opacity(0.3))
                            .blur(radius: 2)
                            .offset(x: 1, y: 1)
                    )
                
                Text("一基暴富")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(
                        colorScheme == .dark ?
                        Color.white.opacity(0.9) :
                        Color(hex: "3E2723")
                    )
                    .shadow(
                        color: colorScheme == .dark ?
                            Color.black.opacity(0.3) :
                            Color.gray.opacity(0.2),
                        radius: 2, x: 1, y: 1
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .opacity(animationOpacity)
            .offset(y: animationOffset)
        }
    }

    private var formSection: some View {
        VStack(spacing: 12) {
            inputCard(
                systemImage: "person.fill",
                gradientColors: [Color(hex: "4facfe"), Color(hex: "00f2fe")],
                placeholder: "请输入用户名",
                text: $username,
                isSecure: false,
                showPassword: $showPassword
            )

            inputCard(
                systemImage: "lock.fill",
                gradientColors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                placeholder: "请输入密码",
                text: $password,
                isSecure: !showPassword,
                showPassword: $showPassword
            )

            if !isLogin {
                inputCard(
                    systemImage: "lock.rotation",
                    gradientColors: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                    placeholder: "请确认密码",
                    text: $confirmPassword,
                    isSecure: !showPassword,
                    showPassword: $showPassword
                )
            }
        }
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    // 生物识别登录部分
    private var biometricLoginSection: some View {
        Button(action: {
            performBiometricLogin()
        }) {
            HStack {
                if isBiometricLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("\(authService.biometricType)验证中...")
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: authService.biometricType == "Face ID" ? "faceid" : "touchid")
                        .font(.system(size: 20))
                    Text("使用\(authService.biometricType)登录")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isBiometricLoading)
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    private var captchaSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "ff9a9e"), Color(hex: "fecfef")]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
            
            TextField("请输入验证码", text: $captcha)
                .textContentType(.oneTimeCode)
                .font(.system(size: 16))
            
            Button(action: {
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
                        authService.fetchCaptcha()
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
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

    private func inputCard(
        systemImage: String,
        gradientColors: [Color],
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        showPassword: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
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
            
            if isSecure {
                HStack {
                    SecureField(placeholder, text: text)
                        .font(.system(size: 16))
                    
                    Button(action: {
                        showPassword.wrappedValue.toggle()
                    }) {
                        Image(systemName: showPassword.wrappedValue ? "eye.slash.circle.fill" : "eye.circle.fill")
                            .foregroundColor(showPassword.wrappedValue ? .orange : .blue)
                            .font(.system(size: 20))
                    }
                }
            } else {
                TextField(placeholder, text: text)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .font(.system(size: 16))
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 4)
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
    
    // 检查生物识别可用性
    private func checkBiometricAvailability() {
        showBiometricOption = authService.isBiometricEnabled && authService.canUseBiometric && isLogin
    }
    
    // 执行生物识别登录
    private func performBiometricLogin() {
        isBiometricLoading = true
        message = ""
        
        authService.loginWithBiometric { success, msg in
            isBiometricLoading = false
            handleAuthResult(success: success, message: msg)
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
            
            // 登录成功后，询问用户是否要启用生物识别登录
            if isLogin && !authService.isBiometricEnabled {
                showBiometricEnableAlert()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } else {
            messageColor = .red
            self.message = message
        }
    }
    
    // 显示启用生物识别弹窗
    private func showBiometricEnableAlert() {
        biometricAlertMessage = "是否要启用\(authService.biometricType)登录？下次登录时可以直接使用\(authService.biometricType)。"
        showBiometricAlert = true
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
