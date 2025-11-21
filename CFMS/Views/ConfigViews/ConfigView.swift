import SwiftUI
import UniformTypeIdentifiers

// MARK: - 主题模式枚举
enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "浅色"
    case dark = "深色"
    case system = "系统"
    
    var id: String { self.rawValue }
}

// MARK: - 自定义卡片视图
struct CustomCardView<Content: View>: View {
    var title: String?
    var description: String?
    var imageName: String?
    var backgroundColor: Color = .white
    var contentForegroundColor: Color = .primary
    var action: (() -> Void)? = nil
    var toggleBinding: Binding<Bool>? = nil
    var toggleTint: Color = .accentColor
    var hasAnimatedBackground: Bool = false

    @State private var hueRotation: Double = 0.0

    @ViewBuilder let content: (Color) -> Content

    var body: some View {
        let cardContent = VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                if let imageName = imageName {
                    Image(systemName: imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(contentForegroundColor)
                }

                if let title = title {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(contentForegroundColor)
                }

                Spacer()

                if let toggleBinding = toggleBinding {
                    Toggle(isOn: toggleBinding) {
                        EmptyView()
                    }
                    .labelsHidden()
                    .tint(toggleTint)
                }
            }

            if let description = description, toggleBinding == nil {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(contentForegroundColor.opacity(0.7))
                    .lineLimit(2)
            }
            
            content(contentForegroundColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(
            ZStack {
                if hasAnimatedBackground {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.7, green: 0.8, blue: 0.9),
                                    Color(red: 0.9, green: 0.7, blue: 0.8),
                                    Color(red: 0.9, green: 0.8, blue: 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .hueRotation(.degrees(hueRotation))
                        .animation(
                            Animation.easeInOut(duration: 8).repeatForever(autoreverses: true),
                            value: hueRotation
                        )
                } else {
                    backgroundColor
                }
            }
        )
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .onAppear {
            if hasAnimatedBackground {
                hueRotation = 360
            }
        }

        if let action = action {
            Button(action: action) {
                cardContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            cardContent
        }
    }
}

// MARK: - 动画渐变文本
struct AnimatedGradientText: View {
    let text: String
    @State private var gradientOffset: CGFloat = -1.0
    
    var body: some View {
        Text(text)
            .font(.system(size: 16))
            .font(Font.system(size: 16).italic())
            .fontWeight(.regular)
            .foregroundColor(.clear)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.7, green: 0.8, blue: 0.9),
                            Color(red: 0.9, green: 0.7, blue: 0.8),
                            Color(red: 0.9, green: 0.8, blue: 0.7),
                            Color(red: 0.7, green: 0.8, blue: 0.9)
                        ]),
                        startPoint: UnitPoint(x: gradientOffset, y: 0.5),
                        endPoint: UnitPoint(x: gradientOffset + 1.0, y: 0.5)
                    )
                    .mask(
                        Text(text)
                            .font(.system(size: 16))
                            .font(Font.system(size: 16).italic())
                            .fontWeight(.regular)
                    )
                    .animation(
                        Animation.linear(duration: 3).repeatForever(autoreverses: false),
                        value: gradientOffset
                    )
                }
            )
            .fixedSize()
            .onAppear {
                gradientOffset = 1.0
            }
    }
}

// MARK: - 立体感渐变用户名
struct AnimatedGradientUsername: View {
    let username: String
    @State private var gradientOffset: CGFloat = -1.0
    
    // 将用户名首字母大写
    var formattedUsername: String {
        guard !username.isEmpty else { return username }
        return username.prefix(1).uppercased() + username.dropFirst().lowercased()
    }
    
    var body: some View {
        Text(formattedUsername)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(.clear)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "FF6B6B"),
                            Color(hex: "4ECDC4"),
                            Color(hex: "45B7D1"),
                            Color(hex: "96CEB4"),
                            Color(hex: "FFEAA7"),
                            Color(hex: "FF6B6B")
                        ]),
                        startPoint: UnitPoint(x: gradientOffset, y: 0),
                        endPoint: UnitPoint(x: gradientOffset + 1.0, y: 1)
                    )
                    .mask(
                        Text(formattedUsername)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    )
                    // 移除阴影效果，保持纯净的渐变
                    .animation(
                        Animation.linear(duration: 4).repeatForever(autoreverses: false),
                        value: gradientOffset
                    )
                }
            )
            .onAppear {
                gradientOffset = 1.0
            }
    }
}

// MARK: - 用户信息视图
struct UserInfoView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingRedemptionView = false
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        CustomCardView(
            title: nil,
            description: nil,
            imageName: nil,
            backgroundColor: Color.purple.opacity(0.1),
            contentForegroundColor: .purple
        ) { fgColor in
            Group {
                if authService.isLoggedIn, let user = authService.currentUser {
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部区域：用户信息
                        HStack(alignment: .top) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.purple)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // 使用新的立体感渐变用户名组件
                                    AnimatedGradientUsername(username: user.username)
                                    
                                    // 试用剩余时间（仅对 subscribed 用户显示）
                                    if user.userType == "subscribed", let endDate = user.subscriptionEnd {
                                        SubscriptionCountdownView(endDate: endDate)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // 右上角：用户类型徽章 - 使用新的进阶感样式
                            userTypeBadge(user.userType)
                                .frame(width: 75, height: 28)
                        }
                        .padding(.bottom, 8)
                        
                        // 底部区域：升级为VIP和退出登录按钮
                        HStack {
                            // 左下角：升级为VIP按钮
                            if user.userType == "free" {
                                Button(action: {
                                    showingRedemptionView = true
                                }) {
                                    HStack {
                                        Text("升级为VIP")
                                            .font(.system(size: 14))
                                            .foregroundColor(.blue)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // 右下角：退出登录按钮 - 保持按钮样式
                            Button("退出登录") {
                                showingLogoutConfirmation = true
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 75, height: 28)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .frame(height: 100)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("未登录")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("请登录以查看个人信息")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                }
            }
        }
        .sheet(isPresented: $showingRedemptionView) {
            RedemptionView()
        }
        .confirmationDialog("确认退出登录？",
                          isPresented: $showingLogoutConfirmation,
                          titleVisibility: .visible) {
            Button("退出", role: .destructive) {
                authService.logout()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("您确定要退出当前登录的账户吗？")
        }
        .onAppear {
            print("🔧 UserInfoView 出现 - 登录状态: \(authService.isLoggedIn), 用户: \(authService.currentUser?.username ?? "nil")")
        }
    }
    
    private func userTypeBadge(_ userType: String) -> some View {
        Group {
            switch userType {
            case "free":
                FreeUserBadge()
            case "subscribed":
                TrialUserBadge()
            case "vip":
                VIPUserBadge()
            default:
                UnknownUserBadge()
            }
        }
    }
}

// MARK: - 免费用户徽章
struct FreeUserBadge: View {
    var body: some View {
        ZStack {
            // 背景渐变 - 灰色系，简约普通
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "9E9E9E"),
                            Color(hex: "757575"),
                            Color(hex: "616161")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 内阴影效果
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .blendMode(.overlay)
            
            // 文字
            Text("免费用户")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .shadow(color: Color.gray.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 试用用户徽章
struct TrialUserBadge: View {
    @State private var shimmerOffset: CGFloat = -1.0
    
    var body: some View {
        ZStack {
            // 背景渐变 - 银色系，带有光泽
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "E0E0E0"),
                            Color(hex: "B0B0B0"),
                            Color(hex: "909090")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 光泽效果
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.4),
                            Color.clear,
                            Color.white.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 闪烁效果
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.6),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: shimmerOffset * 20)
                .mask(RoundedRectangle(cornerRadius: 6))
                .animation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: false),
                    value: shimmerOffset
                )
            
            // 文字
            Text("试用用户")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "424242"))
                .shadow(color: Color.white.opacity(0.5), radius: 1, x: 0, y: 1)
        }
        .shadow(color: Color.gray.opacity(0.5), radius: 3, x: 0, y: 2)
        .onAppear {
            shimmerOffset = 1.0
        }
    }
}

// MARK: - VIP用户徽章
struct VIPUserBadge: View {
    @State private var glowOpacity: Double = 0.5
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // 背景渐变 - 金色系，豪华感
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "FFD700"),
                            Color(hex: "FFA500"),
                            Color(hex: "FF8C00")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 内层光泽
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.6),
                            Color.clear,
                            Color.white.opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 脉动光晕效果
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "FFD700").opacity(glowOpacity),
                            Color(hex: "FFA500").opacity(glowOpacity * 0.7),
                            Color(hex: "FF8C00").opacity(glowOpacity * 0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .animation(
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: glowOpacity
                )
            
            // 文字
            Text("VIP用户")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "5D4037"))
                .shadow(color: Color.white.opacity(0.8), radius: 1, x: 0, y: 1)
        }
        .shadow(color: Color(hex: "FFA500").opacity(0.5), radius: 4, x: 0, y: 2)
        .onAppear {
            glowOpacity = 0.8
        }
    }
}

// MARK: - 未知用户徽章
struct UnknownUserBadge: View {
    var body: some View {
        ZStack {
            // 背景渐变 - 中性色
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "BDBDBD"),
                            Color(hex: "9E9E9E")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 文字
            Text("未知")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .shadow(color: Color.gray.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 订阅倒计时视图
struct SubscriptionCountdownView: View {
    let endDate: Date
    @State private var timeRemaining: String = ""
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            
            Text("试用剩余: \(timeRemaining)")
                .font(.system(size: 12))
                .foregroundColor(.orange)
        }
        .onAppear {
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: endDate)
        
        if let days = components.day, let hours = components.hour, let minutes = components.minute {
            if days > 0 {
                timeRemaining = "\(days)天\(hours)小时"
            } else if hours > 0 {
                timeRemaining = "\(hours)小时\(minutes)分钟"
            } else {
                timeRemaining = "\(minutes)分钟"
            }
        } else {
            timeRemaining = "计算中..."
        }
    }
}

// MARK: - 功能菜单视图
struct FunctionMenuView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService
    @State private var showingManageHoldingsMenuSheet = false
    @State private var showingAPILogSheet = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 第一行：管理持仓和日志查询
            HStack(spacing: 12) {
                // 管理持仓
                CustomCardView(
                    title: "管理持仓",
                    description: "新增、编辑或清空持仓数据",
                    imageName: "folder.fill",
                    backgroundColor: Color.blue.opacity(0.1),
                    contentForegroundColor: .blue,
                    action: {
                        showingManageHoldingsMenuSheet = true
                    }
                ) { _ in EmptyView() }
                .frame(maxWidth: .infinity)
                
                // 日志查询
                CustomCardView(
                    title: "日志查询",
                    description: "API请求与响应日志",
                    imageName: "doc.text.magnifyingglass",
                    backgroundColor: Color.cyan.opacity(0.1),
                    contentForegroundColor: .cyan,
                    action: {
                        showingAPILogSheet = true
                    }
                ) { _ in EmptyView() }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            
            // 第二行：上传云端和下载本地
            HStack(spacing: 12) {
                // 上传云端
                CustomCardView(
                    title: "上传云端",
                    description: "备份数据到云端",
                    imageName: "icloud.and.arrow.up.fill",
                    backgroundColor: Color.green.opacity(0.1),
                    contentForegroundColor: .green,
                    action: {
                        // 上传云端功能
                    }
                ) { _ in EmptyView() }
                .frame(maxWidth: .infinity)
                
                // 下载本地
                CustomCardView(
                    title: "下载本地",
                    description: "导入数据到本地",
                    imageName: "arrow.down.circle.fill",
                    backgroundColor: Color.orange.opacity(0.1),
                    contentForegroundColor: .orange,
                    action: {
                        // 下载本地功能
                    }
                ) { _ in EmptyView() }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
        }
        .sheet(isPresented: $showingManageHoldingsMenuSheet) {
            ManageHoldingsMenuView()
                .environmentObject(dataManager)
                .environmentObject(fundService)
        }
        .sheet(isPresented: $showingAPILogSheet) {
            APILogView()
                .environmentObject(fundService)
        }
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    var body: some View {
        HStack(spacing: 12) {
            PrivacyModeView()
                .frame(maxWidth: .infinity)
            ThemeModeView()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - 隐私模式视图
struct PrivacyModeView: View {
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled: Bool = true
    
    var body: some View {
        CustomCardView(
            title: "隐私模式",
            description: nil,
            imageName: "lock.fill",
            backgroundColor: Color.mint.opacity(0.1),
            contentForegroundColor: .mint
        ) { fgColor in
            Picker("隐私模式", selection: $isPrivacyModeEnabled) {
                Text("开启").tag(true)
                Text("关闭").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - 主题模式视图
struct ThemeModeView: View {
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system
    
    var body: some View {
        CustomCardView(
            title: "主题模式",
            description: nil,
            imageName: "paintbrush.fill",
            backgroundColor: Color.teal.opacity(0.1),
            contentForegroundColor: .teal
        ) { fgColor in
            Picker("主题", selection: $themeMode) {
                ForEach(ThemeMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: themeMode) { newValue in
                applyTheme(newValue)
            }
        }
    }

    private func applyTheme(_ theme: ThemeMode) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        switch theme {
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
}

// MARK: - 服务设置视图
struct ServiceSettingsView: View {
    @State private var showingAboutSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            FundAPIView()
                .frame(maxWidth: .infinity)
            
            CustomCardView(
                title: "关于",
                description: "程序版本信息和说明",
                imageName: "info.circle.fill",
                contentForegroundColor: .white,
                action: {
                    showingAboutSheet = true
                },
                hasAnimatedBackground: true
            ) { _ in EmptyView() }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .sheet(isPresented: $showingAboutSheet) {
            AboutView()
        }
    }
}

// MARK: - 基金API视图
struct FundAPIView: View {
    @AppStorage("selectedFundAPI") private var selectedFundAPI: FundAPI = .eastmoney
    @EnvironmentObject var fundService: FundService
    
    var body: some View {
        CustomCardView(
            title: "数据接口",
            description: nil,
            imageName: "network",
            backgroundColor: Color.blue.opacity(0.1),
            contentForegroundColor: .blue
        ) { fgColor in
            VStack(alignment: .leading, spacing: 8) {
                Menu {
                    ForEach(FundAPI.allCases) { api in
                        Button(action: {
                            selectedFundAPI = api
                            Task {
                                await fundService.addLog("数据接口已切换至: \(api.rawValue)", type: .info)
                            }
                        }) {
                            Text(api.rawValue)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedFundAPI.rawValue)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - 管理持仓菜单视图
struct ManageHoldingsMenuView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService
    @Environment(\.dismiss) var dismiss

    @State private var showingAddSheet = false
    @State private var showingManageHoldingsSheet = false
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    Section {
                        CustomCardView(
                            title: "新增持仓",
                            description: "添加新的基金持仓记录",
                            imageName: "plus.circle.fill",
                            backgroundColor: Color.green.opacity(0.1),
                            contentForegroundColor: .green
                        ) { _ in EmptyView() }
                        .onTapGesture {
                            showingAddSheet = true
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .padding(.bottom, 12)

                        CustomCardView(
                            title: "编辑持仓",
                            description: "管理现有持仓，包括修改和删除",
                            imageName: "pencil.circle.fill",
                            backgroundColor: Color.blue.opacity(0.1),
                            contentForegroundColor: .blue
                        ) { _ in EmptyView() }
                        .onTapGesture {
                            showingManageHoldingsSheet = true
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .padding(.bottom, 12)

                        CustomCardView(
                            title: "清空持仓",
                            description: "删除所有基金持仓数据，注意：此操作不可撤销",
                            imageName: "trash.circle.fill",
                            backgroundColor: Color.red.opacity(0.1),
                            contentForegroundColor: .red
                        ) { _ in EmptyView() }
                        .onTapGesture {
                            showingClearConfirmation = true
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .padding(.top, 24)
                    }
                }
                .listStyle(.plain)
                .padding(.top, 20)
                .padding(.horizontal, 16)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            
                            Image(systemName: "chevron.backward.circle")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                        .frame(width: 32, height: 32)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddHoldingView()
                    .environmentObject(dataManager)
                    .environmentObject(fundService)
            }
            .sheet(isPresented: $showingManageHoldingsSheet) {
                ManageHoldingsView()
                    .environmentObject(dataManager)
                    .environmentObject(fundService)
            }
            .confirmationDialog("确认清空所有持仓数据？",
                                 isPresented: $showingClearConfirmation,
                                 titleVisibility: .visible) {
                Button("清空", role: .destructive) {
                    dataManager.holdings.removeAll()
                    dataManager.saveData()
                    Task {
                        await fundService.addLog("ManageHoldingsMenuView: 所有持仓数据已清除。", type: .info)
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("此操作不可撤销，您确定要清除所有持仓数据吗？")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: UUID())
    }
}

// MARK: - 配置主视图
struct ConfigView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var showToast = false
    @State private var toastMessage = ""

    private func showToast(message: String) {
        toastMessage = message
        showToast = true
    }

    private func onAppear() {
        UserDefaults.standard.register(defaults: ["isPrivacyModeEnabled": true])
        UserDefaults.standard.register(defaults: ["themeMode": "system"])
        UserDefaults.standard.register(defaults: ["selectedFundAPI": "eastmoney"])

        let currentTheme = UserDefaults.standard.string(forKey: "themeMode") ?? "system"
        if let theme = ThemeMode(rawValue: currentTheme) {
            applyTheme(theme)
        }
        
        // 调试信息
        print("🔧 ConfigView 出现 - 登录状态: \(authService.isLoggedIn), 用户: \(authService.currentUser?.username ?? "nil")")
    }
    
    private func onDisappear() {
        // 清理操作（如果有）
    }

    private func applyTheme(_ theme: ThemeMode) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        switch theme {
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 12) {
                        // 1. 用户信息区域
                        UserInfoView()
                            .padding(.horizontal, 8)
                        
                        // 2. 功能菜单区域（包含管理持仓、日志查询、上传云端和下载本地）
                        FunctionMenuView()
                        
                        // 3. 设置区域
                        SettingsView()
                        
                        // 4. 服务设置区域
                        ServiceSettingsView()
                        
                        // 底部装饰文本
                        VStack {
                            AnimatedGradientText(text: "Happiness around the corner.")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                    .padding(.vertical, 8)
                }
                .navigationTitle("")
                .navigationBarHidden(true)
                .onAppear(perform: onAppear)
                .onDisappear(perform: onDisappear)
                
                // 使用项目中已定义的 ToastView
                ToastView(message: toastMessage, isShowing: $showToast)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: UUID())
    }
}

// MARK: - 辅助扩展
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension FundHolding {
    func createDeduplicationKey() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let purchaseDateString = dateFormatter.string(from: purchaseDate)
        
        let amountString = String(format: "%.2f", purchaseAmount)
        let sharesString = String(format: "%.2f", purchaseShares)
        
        return "\(clientName)-\(fundCode)-\(amountString)-\(sharesString)-\(purchaseDateString)-\(clientID)-\(remarks)"
    }
}
