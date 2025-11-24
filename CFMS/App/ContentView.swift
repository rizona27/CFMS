// ContentView是应用的根视图，负责处理应用的主布局（Tab Bar）、启动加载动画（Splash Screen）和用户认证流程。
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSplash = true
    @State private var selectedTab = 0
    @State private var isRefreshLocked = false
    @State private var animationFinished = false
    @State private var shouldShowAuthView = false
    @State private var splashOpacity: Double = 1.0
    @State private var mainTextOpacity: Double = 1.0
    @State private var subtitleOpacity: Double = 1.0
    @State private var copyrightOpacity: Double = 1.0
    @State private var mainTextOffset: CGFloat = 0.0
    @State private var subtitleOffset: CGFloat = 0.0
    @State private var highlightPosition: CGFloat = -1.0
    @State private var highlightOpacity: Double = 0.0
    @State private var glowScale: CGFloat = 1.4
    @State private var glowOpacity: Double = 0.0
    @State private var glowRotation: Double = 0.0
    @State private var glowOffset: CGSize = CGSize(width: 30, height: 30)
    @State private var splashBlur: CGFloat = 0.0
    @State private var splashScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if authService.isLoggedIn {
                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case 0:
                            SummaryView()
                                .environmentObject(dataManager)
                        case 1:
                            ClientView()
                                .environmentObject(dataManager)
                        case 2:
                            TopPerformersView()
                                .environmentObject(dataManager)
                        case 3:
                            ConfigView()
                                .environmentObject(dataManager)
                                .environmentObject(authService)
                        default:
                            SummaryView()
                                .environmentObject(dataManager)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    CustomTabBar(selectedTab: $selectedTab)
                        .environmentObject(dataManager)
                }
                .disabled(isRefreshLocked)
                .ignoresSafeArea(.container, edges: [.top, .bottom])
            }

            if showSplash && !authService.isLoggedIn {
                splashScreen
                    .onTapGesture {
                        if animationFinished {
                            shouldShowAuthView = true
                        }
                    }
            }
        }
        .onAppear {
            startNaturalAnimation()
        }
        .sheet(isPresented: $shouldShowAuthView) {
            AuthView()
                .environmentObject(authService)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FileImportedFromShare"))) { notification in
            handleFileImport(notification: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshLockEnabled"))) { _ in
            isRefreshLocked = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshLockDisabled"))) { _ in
            isRefreshLocked = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshAppState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            print("收到内存警告，清理缓存...")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutoLogoutDueToInactivity"))) { _ in
            shouldShowAuthView = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidLogout"))) { _ in
            shouldShowAuthView = true
            showSplash = true
            animationFinished = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CSVImportCompleted"))) { notification in
            handleCSVImportCompleted(notification: notification)
        }
        .toast(message: dataManager.toastMessage, isShowing: $dataManager.showToast)
    }

    private func handleFileImport(notification: Notification) {
        print("ContentView: 收到文件导入通知")
        
        guard let userInfo = notification.userInfo,
              let fileURL = userInfo["fileURL"] as? URL else {
            print("ContentView: 文件导入通知中缺少 fileURL")
            dataManager.toastMessage = "文件信息不完整"
            dataManager.showToast = true
            return
        }
        
        print("ContentView: 准备处理导入的文件: \(fileURL)")
        print("ContentView: 文件路径: \(fileURL.path)")

        guard authService.isLoggedIn else {
            print("ContentView: 用户未登录，无法导入文件")
            dataManager.toastMessage = "请先登录账户"
            dataManager.showToast = true
            return
        }

        // 使用 DataManager 处理文件导入
        Task {
            await dataManager.processImportedFile(url: fileURL)
        }
    }

    private func handleCSVImportCompleted(notification: Notification) {
        print("ContentView: CSV导入处理完成")
        
        guard let userInfo = notification.userInfo,
              let importedCount = userInfo["importedCount"] as? Int,
              let errorCount = userInfo["errorCount"] as? Int else {
            print("ContentView: CSV导入完成通知中缺少数据")
            return
        }
        
        print("ContentView: 导入结果 - 成功: \(importedCount)条, 失败: \(errorCount)条")

        if importedCount > 0 {
            showImportSuccessAlert(importedCount: importedCount, errorCount: errorCount)
        }
    }

    private func showImportSuccessAlert(importedCount: Int, errorCount: Int) {
        let message = "成功导入 \(importedCount) 条记录"
        print("ContentView: \(message)")

        let content = UNMutableNotificationContent()
        content.title = "数据导入完成"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "csvImportSuccess", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

    }

    private var splashScreen: some View {
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

            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: circleGradientColors),
                            center: .center,
                            startRadius: 0,
                            endRadius: 150 + CGFloat(index) * 60
                        )
                    )
                    .frame(
                        width: 250 + CGFloat(index) * 100,
                        height: 250 + CGFloat(index) * 100
                    )
                    .scaleEffect(glowScale * (1.0 - CGFloat(index) * 0.1))
                    .opacity(glowOpacity * (1.0 - Double(index) * 0.2))
                    .rotationEffect(.degrees(glowRotation * Double(index + 1) * 0.3))
                    .offset(glowOffset)
                    .blur(radius: 15 + CGFloat(index) * 5)
            }

            VStack(alignment: .center, spacing: 12) {
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Less")
                            .font(.system(size: 46, weight: .light, design: .serif))
                            .foregroundColor(mainTextColor)
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 2, x: 0, y: 1)
                        
                        Text("is")
                            .font(.system(size: 32, weight: .light, design: .serif))
                            .foregroundColor(mainTextColor)
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 2, x: 0, y: 1)
                    }
                    
                    Text("More.")
                        .font(.system(size: 60, weight: .semibold, design: .serif))
                        .foregroundColor(accentTextColor)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.08), radius: 3, x: 0, y: 2)
                }
                .opacity(mainTextOpacity)
                .offset(y: mainTextOffset)

                Text("Finding Abundance Through Subtraction")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(subtitleColor)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .opacity(subtitleOpacity)
                    .offset(y: subtitleOffset)
                Spacer()
                VStack(spacing: 4) {
                    Text("专业 · 专注 · 价值")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(copyrightColor)
                    
                    Text("Copyright © 2025 Rizona.")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(copyrightColor)
                }
                .opacity(copyrightOpacity)
                .padding(.bottom, 50)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: highlightGradientColors),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 80)
                        .offset(x: highlightPosition * 200)
                        .opacity(highlightOpacity)
                        .blendMode(.plusLighter)
                        .mask(
                            VStack(spacing: 4) {
                                Text("专业 · 专注 · 价值")
                                    .font(.system(size: 13, weight: .light))
                                
                                Text("© 2025 Rizona Developed")
                                    .font(.system(size: 11, weight: .light))
                            }
                        )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
        }
        .opacity(splashOpacity)
        .scaleEffect(splashScale)
        .blur(radius: splashBlur)
        .edgesIgnoringSafeArea(.all)
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
                Color(hex: "E8D5C4").opacity(0.3),
                Color(hex: "F0ECE5").opacity(0.15),
                Color.clear
            ]
        }
    }

    private var mainTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "5D4037")
    }

    private var accentTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "3E2723")
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(hex: "6D4C41").opacity(0.8)
    }

    private var copyrightColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color(hex: "795548").opacity(0.6)
    }

    private var highlightGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.clear,
                Color.white.opacity(0.3),
                Color.white.opacity(0.5),
                Color.white.opacity(0.3),
                Color.clear
            ]
        } else {
            return [
                Color.clear,
                Color.white.opacity(0.4),
                Color.white.opacity(0.6),
                Color.white.opacity(0.4),
                Color.clear
            ]
        }
    }

    private func startNaturalAnimation() {
        splashOpacity = 1.0; mainTextOpacity = 0.0; subtitleOpacity = 0.0; copyrightOpacity = 0.0
        mainTextOffset = 10.0; subtitleOffset = 8.0; highlightPosition = -1.0; highlightOpacity = 0.0
        glowScale = 0.7; glowOpacity = 0.0; glowRotation = 0.0; glowOffset = CGSize(width: -100, height: -100)
        splashBlur = 0.0; splashScale = 1.0; animationFinished = false; shouldShowAuthView = false

        withAnimation(.easeOut(duration: 2.5)) {
            glowScale = 1.4
            glowOpacity = 0.4
            glowOffset = CGSize(width: 30, height: 30)
        }

        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            glowRotation = 360
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 1.2)) {
                mainTextOpacity = 1.0
                mainTextOffset = 0.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 1.0)) {
                subtitleOpacity = 1.0
                subtitleOffset = 0.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.8)) {
                copyrightOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.1)) { highlightOpacity = 1.0 }
                withAnimation(.easeInOut(duration: 0.8)) { highlightPosition = 1.0 }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.easeOut(duration: 0.3)) { highlightOpacity = 0.0 }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeIn(duration: 0.8)) { glowOpacity = 0.0 }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                glowRotation = 0.0
                animationFinished = true

                if !authService.isLoggedIn {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shouldShowAuthView = true
                    }
                }
            }
        }
    }

    private func refreshAppState() {
        print("ContentView: App became active, refreshing state...")
        if !authService.isLoggedIn && animationFinished {
            shouldShowAuthView = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let dataManager = DataManager()
        let authService = AuthService()
        let fundService = FundService()

        if dataManager.holdings.isEmpty {
            let holding1 = FundHolding(
                clientName: "张三",
                clientID: "A001",
                fundCode: "000001",
                purchaseAmount: 5000.0,
                purchaseShares: 2000.0,
                purchaseDate: Date().addingTimeInterval(-86400 * 180),
                remarks: "首次购买",
                fundName: "华夏成长混合 (预览)",
                currentNav: 2.50,
                navDate: Date()
            )
            let holding2 = FundHolding(
                clientName: "李四",
                clientID: "B002",
                fundCode: "000002",
                purchaseAmount: 2500.0,
                purchaseShares: 781.25,
                purchaseDate: Date().addingTimeInterval(-86400 * 90),
                remarks: "追加投资",
                fundName: "南方稳健增长 (预览)",
                currentNav: 3.20,
                navDate: Date()
            )

            DispatchQueue.main.async {
                do {
                    try dataManager.addHolding(holding1)
                    try dataManager.addHolding(holding2)
                } catch {
                    print("添加预览数据失败: \(error)")
                }
            }
        }

        return ContentView()
            .environmentObject(dataManager)
            .environmentObject(authService)
            .environmentObject(fundService)
    }
}
