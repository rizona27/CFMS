//设置页面主视图
import SwiftUI
import UniformTypeIdentifiers

enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "浅色"
    case dark = "深色"
    case system = "系统"
    
    var id: String { self.rawValue }
}

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
    var userType: AuthService.UserType? = nil
    var isCompact: Bool = false
    var hasGradientBackground: Bool = true

    @State private var hueRotation: Double = 0.0
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder let content: (Color) -> Content

    var body: some View {
        let cardContent = ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    if let imageName = imageName {
                        Image(systemName: imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: isCompact ? 24 : 28, height: isCompact ? 24 : 28)
                            .foregroundColor(contentForegroundColor)
                    }

                    if let title = title {
                        Text(title)
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
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
                        .font(.system(size: isCompact ? 11 : 12))
                        .foregroundColor(contentForegroundColor.opacity(0.7))
                        .lineLimit(2)
                }
                
                content(contentForegroundColor)
            }
            .padding(isCompact ? 10 : 12)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 80 : 100, alignment: .leading)

            if let userType = userType {
                UserTypeRibbon(userType: userType)
                    .offset(x: isCompact ? 6 : 8, y: isCompact ? -6 : -8)
            }
        }
        .background(
            ZStack {
                if hasAnimatedBackground {
                    // 修改点2: 为动画背景添加遮罩，使其呈现左上到右下的减淡效果
                    ZStack {
                        // 底层动态背景
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
                        
                        // 叠加层保持不变，提供基础的光泽感
                        RoundedRectangle(cornerRadius: 15)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: getOverlayGradientColors()),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    // 关键修改：通过Mask实现"减淡"效果，让右下角逐渐透明，与普通卡片风格统一
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .black.opacity(0.15)]), // 从完全不透明过渡到低透明度
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    
                } else if hasGradientBackground {
                    // 45°渐变背景
                    RoundedRectangle(cornerRadius: 15)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: getGradientColors()),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    backgroundColor
                }
            }
        )
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(getGlowColor(for: userType), lineWidth: userType == .subscribed ? 1.5 : (userType == .vip ? 2 : 0))
                .blur(radius: userType == .subscribed ? 2 : (userType == .vip ? 2.5 : 0))
                .opacity(userType == .subscribed ? 0.6 : (userType == .vip ? 0.7 : 0))
                .padding(userType == .subscribed ? 0.5 : (userType == .vip ? 1 : 0))
        )
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
    
    private func getGlowColor(for userType: AuthService.UserType?) -> Color {
        switch userType {
        case .subscribed:
            return Color(hex: "E0E0E0")
        case .vip:
            return Color(hex: "FFE55C")
        default:
            return .clear
        }
    }
    
    private func getGradientColors() -> [Color] {
        // 在深色模式下使用更浅的渐变，确保卡片可见
        if colorScheme == .dark {
            let baseColor = backgroundColor
            let endColor = baseColor.opacity(0.3) // 使用更浅的渐变结束色
            return [baseColor, endColor]
        } else {
            let baseColor = backgroundColor
            let endColor = Color.white.opacity(0.8)
            return [baseColor, endColor]
        }
    }
    
    private func getOverlayGradientColors() -> [Color] {
        // 用于动画背景上的叠加渐变
        if colorScheme == .dark {
            return [Color.clear, Color.black.opacity(0.3)]
        } else {
            return [Color.clear, Color.white.opacity(0.6)]
        }
    }
}

struct UserTypeRibbon: View {
    let userType: AuthService.UserType
    @State private var shimmerOffset: CGFloat = -80.0
    @State private var hasAnimated = false // 新增状态控制
    
    var ribbonText: String {
        switch userType {
        case .free:
            return "基础用户"
        case .subscribed:
            return "体验用户"
        case .vip:
            return "尊享用户"
        }
    }
    
    var ribbonColor: LinearGradient {
        switch userType {
        case .free:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "9E9E9E"),
                    Color(hex: "757575"),
                    Color(hex: "616161")
                ]),
                // 修改点2: 将渐变方向从左到右
                startPoint: .leading,
                endPoint: .trailing
            )
        case .subscribed:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "E0E0E0"),
                    Color(hex: "B0B0B0"),
                    Color(hex: "909090")
                ]),
                // 修改点2: 将渐变方向从左到右
                startPoint: .leading,
                endPoint: .trailing
            )
        case .vip:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "FFD700"),
                    Color(hex: "FFA500"),
                    Color(hex: "FF8C00")
                ]),
                // 修改点2: 将渐变方向从左到右
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    var textColor: Color {
        switch userType {
        case .free, .vip:
            return .white
        case .subscribed:
            return Color(hex: "424242")
        }
    }
    
    var body: some View {
        ZStack {
            // 绶带背景
            Rectangle()
                .fill(ribbonColor)
                .frame(width: 80, height: 24)
                .rotationEffect(.degrees(45))
                .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 1.5)
                .overlay(
                    // 修改点1: 改进的高光效果 - 使用叠加层和Offset实现锐利的扫光
                    Group {
                        if userType == .subscribed || userType == .vip {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .clear,
                                            .white.opacity(0.2),
                                            .white.opacity(0.9), // 高亮核心
                                            .white.opacity(0.2),
                                            .clear
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 30, height: 24) // 较窄的高光条
                                .offset(x: shimmerOffset)
                                .rotationEffect(.degrees(45)) // 随绶带旋转
                                .mask(
                                    // 确保高光只在绶带区域内显示
                                    Rectangle()
                                        .frame(width: 80, height: 24)
                                        .rotationEffect(.degrees(45))
                                )
                        }
                    }
                )
            
            // 文字
            Text(ribbonText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textColor)
                .rotationEffect(.degrees(45))
                .shadow(color: userType == .subscribed ? .white.opacity(0.3) : .black.opacity(0.2),
                       radius: 0.5, x: 0, y: 0.5)
        }
        .frame(width: 60, height: 60)
        .onAppear {
            // 只在第一次出现时执行动画，或者重置状态后
            if !hasAnimated && (userType == .subscribed || userType == .vip) {
                hasAnimated = true
                shimmerOffset = -80.0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(
                        Animation.linear(duration: 2.0)
                    ) {
                        shimmerOffset = 80.0
                    }
                }
            }
        }
        .onDisappear {
            // 当离开页面时重置动画状态，这样下次进入时可以重新执行
            hasAnimated = false
            shimmerOffset = -80.0
        }
    }
}

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

struct AnimatedGradientUsername: View {
    let username: String
    let userType: AuthService.UserType
    @State private var gradientOffset: CGFloat = -1.0

    var formattedUsername: String {
        guard !username.isEmpty else { return username }
        return username.prefix(1).uppercased() + username.dropFirst().lowercased()
    }
    
    var body: some View {
        if userType == .free {
            Text(formattedUsername)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .italic()
                .foregroundColor(.primary)
        } else {
            Text(formattedUsername)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .italic()
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
                                .italic()
                        )
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
}

struct UserInfoView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingRedemptionView = false
    @State private var showingLogoutConfirmation = false

    private var cardColors: (backgroundColor: Color, foregroundColor: Color) {
        guard let userType = authService.currentUser?.userType else {
            return (Color.gray.opacity(0.1), .gray)
        }
        
        switch userType {
        case .free:
            return (Color.blue.opacity(0.1), .blue)
        case .subscribed:
            return (Color(hex: "F5F5F5").opacity(0.9), Color(hex: "606060"))
        case .vip:
            return (Color(hex: "FFFDE7").opacity(0.8), Color(hex: "B8860B"))
        }
    }

    private var iconColor: Color {
        guard let userType = authService.currentUser?.userType else {
            return .gray
        }
        
        switch userType {
        case .free:
            return .blue
        case .subscribed:
            return Color(hex: "606060")
        case .vip:
            return Color(hex: "B8860B")
        }
    }
    
    var body: some View {
        let colors = cardColors
        
        VStack(alignment: .leading, spacing: 8) {
            CustomCardView(
                title: nil,
                description: nil,
                imageName: nil,
                backgroundColor: colors.backgroundColor,
                contentForegroundColor: colors.foregroundColor,
                userType: authService.currentUser?.userType,
                isCompact: true,
                hasGradientBackground: false
            ) { fgColor in
                Group {
                    if authService.isLoggedIn, let user = authService.currentUser {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(iconColor)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        AnimatedGradientUsername(username: user.username, userType: user.userType)

                                        if user.userType == .subscribed, let endDateText = authService.getSubscriptionEndDateForDisplay() {
                                            Text(endDateText)
                                                .font(.system(size: 11))
                                                .foregroundColor(.orange)
                                        } else if user.userType == .vip {
                                            Text("永久有效")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(hex: "B8860B"))
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.bottom, 8)

                            HStack {
                                if user.userType == .free || user.userType == .subscribed {
                                    Button(action: {
                                        showingRedemptionView = true
                                    }) {
                                        HStack {
                                            Text("升级")
                                                .font(.system(size: 14))
                                                .foregroundColor(colors.foregroundColor)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(colors.foregroundColor)
                                        }
                                    }
                                }
                                
                                Spacer()

                                Button("退出") {
                                    showingLogoutConfirmation = true
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 75, height: 28)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .frame(height: 80)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            
                            Text("未登录")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("请登录以查看个人信息")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                    }
                }
            }
            .padding(.horizontal, 16)

            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .padding(.top, 8)
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
}

struct FunctionMenuView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService
    @EnvironmentObject var authService: AuthService
    
    @State private var showingManageHoldingsMenuSheet = false
    @State private var showingAPILogSheet = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
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
            
            // 修改点1: 在基础用户模式下隐藏上传云端和下载本地卡片
            if authService.currentUser?.userType != .free {
                HStack(spacing: 12) {
                    CustomCardView(
                        title: "上传云端",
                        description: "备份数据到云端",
                        imageName: "icloud.and.arrow.up.fill",
                        backgroundColor: Color.green.opacity(0.1),
                        contentForegroundColor: .green,
                        action: {
                        }
                    ) { _ in EmptyView() }
                    .frame(maxWidth: .infinity)

                    CustomCardView(
                        title: "下载本地",
                        description: "导入数据到本地",
                        imageName: "arrow.down.circle.fill",
                        backgroundColor: Color.orange.opacity(0.1),
                        contentForegroundColor: .orange,
                        action: {
                        }
                    ) { _ in EmptyView() }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.top, 8)
        .sheet(isPresented: $showingManageHoldingsMenuSheet) {
            ManageHoldingsMenuView()
                .environmentObject(dataManager)
                .environmentObject(fundService)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingAPILogSheet) {
            APILogView()
                .environmentObject(fundService)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        HStack(spacing: 12) {
            PrivacyModeView()
                .frame(maxWidth: .infinity)
            ThemeModeView()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

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
                backgroundColor: Color.blue.opacity(0.1), // 添加基础背景色
                contentForegroundColor: .white,
                action: {
                    showingAboutSheet = true
                },
                hasAnimatedBackground: true,
                hasGradientBackground: true // 启用45°渐变背景
            ) { _ in EmptyView() }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .sheet(isPresented: $showingAboutSheet) {
            AboutView()
        }
    }
}

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

struct ManageHoldingsMenuView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService
    @EnvironmentObject var authService: AuthService
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
                    .environmentObject(authService)
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
        print("🔧 ConfigView 出现 - 登录状态: \(authService.isLoggedIn), 用户: \(authService.currentUser?.username ?? "nil")")
    }
    
    private func onDisappear() {
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
                    VStack(spacing: 0) {
                        UserInfoView()
                        FunctionMenuView()
                        SettingsView()
                        ServiceSettingsView()
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

                ToastView(message: toastMessage, isShowing: $showToast)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: UUID())
    }
}

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
