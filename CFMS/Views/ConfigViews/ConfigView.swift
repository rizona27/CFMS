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
                        HStack(alignment: .top) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.purple)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    AnimatedGradientUsername(username: user.username, userType: user.userType)

                                    if user.userType == .subscribed, let endDateText = authService.getSubscriptionEndDateForDisplay() {
                                        Text(endDateText)
                                            .font(.system(size: 11))
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            
                            Spacer()

                            userTypeBadge(user.userType)
                                .frame(width: 75, height: 28)
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
                                            .foregroundColor(.blue)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Spacer()

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
    
    private func userTypeBadge(_ userType: AuthService.UserType) -> some View {
        Group {
            switch userType {
            case .free:
                BasicUserBadge()
            case .subscribed:
                ExperienceUserBadge()
            case .vip:
                PremiumUserBadge()
            }
        }
    }
}

struct BasicUserBadge: View {
    var body: some View {
        ZStack {
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

            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .blendMode(.overlay)

            Text("基础用户")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .shadow(color: Color.gray.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

struct ExperienceUserBadge: View {
    @State private var shimmerOffset: CGFloat = -1.0
    
    var body: some View {
        ZStack {
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

            Text("体验用户")
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

struct PremiumUserBadge: View {
    @State private var glowOpacity: Double = 0.5
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
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

            Text("尊享用户")
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

struct UnknownUserBadge: View {
    var body: some View {
        ZStack {
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

            Text("未知")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .shadow(color: Color.gray.opacity(0.4), radius: 2, x: 0, y: 1)
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
                    VStack(spacing: 12) {
                        UserInfoView()
                            .padding(.horizontal, 8)
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
