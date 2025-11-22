//后端认证模块
import Foundation
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

class AuthService: ObservableObject {
    let baseURL = "https://cfms.crnas.uk:8315"
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var authToken: String?

    // 新增：验证码相关
    @Published var captchaImage: UIImage?
    @Published var captchaId: String?

    enum UserType: String {
        case free = "free"
        case subscribed = "subscribed"
        case vip = "vip"
    }

    private var inactivityTimer: Timer?
    private let inactivityTimeout: TimeInterval = 5 * 60
    private let backgroundTimeout: TimeInterval = 5 * 60
    private var lastActivityTime: Date = Date()
    private var backgroundEnterTime: Date?

    private let maxAuthAttempts = 3
    private let maxAuthAttemptsBeforeCaptcha = 5
    private let authLockoutDuration: TimeInterval = 10 * 60
    private let registerCooldownDuration: TimeInterval = 24 * 60 * 60
    private let maxRegistrationsPerDevice = 2
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    init() {
        print("🔧 AuthService 初始化")
        checkLoginStatus()
        setupInactivityMonitoring()
        setupAppStateMonitoring()
    }

    func getSubscriptionEndDate() -> String? {
        guard let user = currentUser, user.userType == .subscribed else {
            return nil
        }
        
        guard let endDate = user.subscriptionEnd else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "zh_CN")
        
        return formatter.string(from: endDate)
    }
    
    func getSubscriptionEndDateForDisplay() -> String? {
        guard let endDateString = getSubscriptionEndDate() else {
            return nil
        }
        
        return "到期时间: \(endDateString)"
    }
    
    var isSubscriptionActive: Bool {
        guard let user = currentUser, user.userType == .subscribed else {
            return false
        }
        
        guard let endDate = user.subscriptionEnd else {
            return false
        }
        
        return endDate > Date()
    }
    
    var subscriptionDaysRemaining: Int? {
        guard let user = currentUser, user.userType == .subscribed,
              let endDate = user.subscriptionEnd else {
            return nil
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return components.day
    }

    func canRegister() -> (canRegister: Bool, remainingTime: TimeInterval?) {
        let authCheck = canAuth()
        if !authCheck.canAuth {
            return (false, authCheck.remainingTime)
        }

        let registeredCount = getRegisteredAccountsCount()
        if registeredCount >= maxRegistrationsPerDevice {
            return (false, nil)
        }

        if let lastRegisterTime = UserDefaults.standard.object(forKey: "lastRegisterTime") as? Date {
            let elapsedTime = Date().timeIntervalSince(lastRegisterTime)
            if elapsedTime < registerCooldownDuration {
                let remainingTime = registerCooldownDuration - elapsedTime
                return (false, remainingTime)
            }
        }
        return (true, nil)
    }

    private func getRegisteredAccountsCount() -> Int {
        return UserDefaults.standard.integer(forKey: "registeredAccountsCount")
    }

    private func incrementRegisteredAccountsCount() {
        let count = getRegisteredAccountsCount() + 1
        UserDefaults.standard.set(count, forKey: "registeredAccountsCount")
        print("🔧 设备已注册账户数量: \(count)")
    }
    
    func canLogin() -> (canLogin: Bool, remainingTime: TimeInterval?) {
        let authResult = canAuth()
        return (canLogin: authResult.canAuth, remainingTime: authResult.remainingTime)
    }

    func requiresCaptcha() -> Bool {
        let failedAttempts = UserDefaults.standard.integer(forKey: "authFailedAttempts")
        return failedAttempts >= 3
    }

    func canAuth() -> (canAuth: Bool, remainingTime: TimeInterval?) {
        let failedAttempts = UserDefaults.standard.integer(forKey: "authFailedAttempts")

        if failedAttempts >= maxAuthAttemptsBeforeCaptcha {
            if let lockoutTime = UserDefaults.standard.object(forKey: "authLockoutTime") as? Date {
                let elapsedTime = Date().timeIntervalSince(lockoutTime)
                if elapsedTime < authLockoutDuration {
                    let remainingTime = authLockoutDuration - elapsedTime
                    return (false, remainingTime)
                } else {
                    UserDefaults.standard.set(0, forKey: "authFailedAttempts")
                    UserDefaults.standard.removeObject(forKey: "authLockoutTime")
                }
            } else {
                UserDefaults.standard.set(Date(), forKey: "authLockoutTime")
                return (false, authLockoutDuration)
            }
        }
        
        return (true, nil)
    }

    private func recordAuthFailure() {
        var failedAttempts = UserDefaults.standard.integer(forKey: "authFailedAttempts")
        failedAttempts += 1
        UserDefaults.standard.set(failedAttempts, forKey: "authFailedAttempts")
        
        print("🔧 认证失败次数: \(failedAttempts)")
        
        if failedAttempts >= maxAuthAttemptsBeforeCaptcha {
            UserDefaults.standard.set(Date(), forKey: "authLockoutTime")
            print("🔧 认证已被锁定，请10分钟后再试")
        }
    }

    private func recordRegisterTime() {
        UserDefaults.standard.set(Date(), forKey: "lastRegisterTime")
        incrementRegisteredAccountsCount()
    }
    
    private func resetAuthFailure() {
        UserDefaults.standard.set(0, forKey: "authFailedAttempts")
        UserDefaults.standard.removeObject(forKey: "authLockoutTime")
    }

    func getLastUsername() -> String {
        return UserDefaults.standard.string(forKey: "lastUsername") ?? ""
    }

    private func saveLastUsername(_ username: String) {
        UserDefaults.standard.set(username, forKey: "lastUsername")
    }

    func shouldRememberUsername() -> Bool {
        return UserDefaults.standard.bool(forKey: "rememberUsername")
    }

    func setRememberUsername(_ remember: Bool) {
        UserDefaults.standard.set(remember, forKey: "rememberUsername")
    }
    
    // 新增：获取验证码图片
    func fetchCaptcha() {
        guard let url = URL(string: "\(baseURL)/api/captcha") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success,
                       let base64String = json["image_base64"] as? String,
                       let captchaId = json["captcha_id"] as? String,
                       let imageData = Data(base64Encoded: base64String),
                       let image = UIImage(data: imageData) {
                        
                        DispatchQueue.main.async {
                            self.captchaImage = image
                            self.captchaId = captchaId
                            print("🔧 验证码获取成功，ID: \(captchaId)")
                        }
                    }
                } catch {
                    print("🔧 验证码解析失败: \(error)")
                }
            }
        }.resume()
    }

    func login(username: String, password: String, captcha: String? = nil, completion: @escaping (Bool, String) -> Void) {
        print("🔧 开始登录流程，用户名: \(username)")

        let loginCheck = canLogin()
        if !loginCheck.canLogin {
            if let remainingTime = loginCheck.remainingTime {
                let minutes = Int(ceil(remainingTime / 60))
                completion(false, "登录尝试次数过多，请\(minutes)分钟后再试")
                return
            }
        }

        // 修改：验证码校验逻辑 (此处仅做非空校验，真正校验由后端完成)
        if requiresCaptcha() {
            guard let captcha = captcha, !captcha.isEmpty else {
                completion(false, "请输入验证码")
                return
            }
            
            // 前端不再校验 "1234"，而是必须确保已经获取到了验证码ID
            if self.captchaId == nil {
                completion(false, "验证码加载失败，请点击刷新")
                return
            }
        }
        
        guard let url = URL(string: "\(baseURL)/api/login") else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        // 如果需要验证码，添加到请求体
        if let captchaCode = captcha, let captchaId = self.captchaId, !captchaCode.isEmpty {
            body["captcha_code"] = captchaCode
            body["captcha_id"] = captchaId
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "请求数据错误")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // 网络错误不一定算作认证失败，但为了安全可以记录
                    self.recordAuthFailure()
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.recordAuthFailure()
                    completion(false, "没有收到数据")
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔧 登录响应: \(responseString)")
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            let token = json["token"] as? String ?? ""
                            
                            let userData = json["user_info"] as? [String: Any] ?? [:]
                            
                            print("🔧 登录成功，用户数据: \(userData)")
                            
                            self.saveLoginStatus(token: token, userData: userData)
                            self.saveLastUsername(username)
                            
                            self.isLoggedIn = true
                            self.authToken = token
                            self.currentUser = User(from: userData)
                            self.resetInactivityTimer()
                            
                            // 登录成功，清除验证码相关状态
                            self.resetAuthFailure()
                            self.captchaImage = nil
                            self.captchaId = nil
                            
                            self.objectWillChange.send()
                            
                            print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil")")
                            
                            completion(true, json["message"] as? String ?? "登录成功")
                        } else {
                            // 登录失败，记录次数
                            self.recordAuthFailure()
                            // 登录失败后，刷新验证码
                            if self.requiresCaptcha() {
                                self.fetchCaptcha()
                            }
                            let message = json["message"] as? String ?? json["error"] as? String ?? "登录失败"
                            completion(false, message)
                        }
                    } else {
                        self.recordAuthFailure()
                        completion(false, "响应格式错误")
                    }
                } catch {
                    self.recordAuthFailure()
                    completion(false, "数据解析错误: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    func register(username: String, password: String, confirmPassword: String, completion: @escaping (Bool, String) -> Void) {
        print("🔧 开始注册流程，用户名: \(username)")
        
        let authCheck = canAuth()
        if !authCheck.canAuth {
            if let remainingTime = authCheck.remainingTime {
                let minutes = Int(ceil(remainingTime / 60))
                completion(false, "认证尝试次数过多，请\(minutes)分钟后再试")
                return
            }
        }
        
        let registerCheck = canRegister()
        if !registerCheck.canRegister {
            if let remainingTime = registerCheck.remainingTime {
                let hours = Int(ceil(remainingTime / 3600))
                if hours > 0 {
                    completion(false, "注册过于频繁，请\(hours)小时后再试")
                } else {
                    let minutes = Int(ceil(remainingTime / 60))
                    completion(false, "注册过于频繁，请\(minutes)分钟后再试")
                }
                return
            } else {
                completion(false, "当前设备注册账户数量已达上限")
                return
            }
        }
        
        guard password == confirmPassword else {
            completion(false, "密码不一致")
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/register") else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "请求数据错误")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.recordAuthFailure()
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.recordAuthFailure()
                    completion(false, "没有收到数据")
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔧 注册响应: \(responseString)")
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            let token = json["token"] as? String ?? ""
                            
                            let userData = json["user_info"] as? [String: Any] ?? [:]
                            
                            print("🔧 注册成功，用户数据: \(userData)")
                            
                            self.saveLoginStatus(token: token, userData: userData)
                            self.saveLastUsername(username)
                            
                            self.recordRegisterTime()
                            self.resetAuthFailure()
                            
                            self.isLoggedIn = true
                            self.authToken = token
                            self.currentUser = User(from: userData)
                            self.resetInactivityTimer()
                            
                            self.objectWillChange.send()
                            
                            completion(true, json["message"] as? String ?? "注册成功")
                        } else {
                            self.recordAuthFailure()
                            let message = json["message"] as? String ?? json["error"] as? String ?? "注册失败"
                            completion(false, message)
                        }
                    } else {
                        self.recordAuthFailure()
                        completion(false, "响应格式错误")
                    }
                } catch {
                    self.recordAuthFailure()
                    completion(false, "数据解析错误: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    func logout() {
        print("🔧 执行退出登录")
        
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userData")
        
        self.isLoggedIn = false
        self.authToken = nil
        self.currentUser = nil
        
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        
        self.objectWillChange.send()
        
        print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil")")
        
        NotificationCenter.default.post(
            name: NSNotification.Name("UserDidLogout"),
            object: nil
        )
    }

    private func saveLoginStatus(token: String, userData: [String: Any]) {
        UserDefaults.standard.set(token, forKey: "authToken")
        if let userJsonData = try? JSONSerialization.data(withJSONObject: userData) {
            UserDefaults.standard.set(userJsonData, forKey: "userData")
        }
        print("🔧 登录状态已保存到 UserDefaults")
    }

    private func checkLoginStatus() {
        print("🔧 检查登录状态")
        
        if let token = UserDefaults.standard.string(forKey: "authToken"),
           let userData = UserDefaults.standard.data(forKey: "userData"),
           let userDict = try? JSONSerialization.jsonObject(with: userData) as? [String: Any] {
            
            print("🔧 找到保存的登录信息，token: \(token.prefix(10))..., userData: \(userDict)")
            
            self.authToken = token
            self.currentUser = User(from: userDict)
            self.isLoggedIn = true
            
            self.objectWillChange.send()
            
            self.resetInactivityTimer()
            
            print("🔧 登录状态恢复完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil"), 类型: \(self.currentUser?.userType.rawValue ?? "unknown"), 订阅结束: \(self.currentUser?.subscriptionEnd?.description ?? "nil")")
        } else {
            print("🔧 没有找到保存的登录信息")
        }
    }

    private func setupInactivityMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidInteract),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }
    
    private func setupAppStateMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func userDidInteract() {
        resetInactivityTimer()
    }
    
    @objc private func appWillResignActive() {
        print("🔧 应用即将进入后台，停止不活跃计时器")
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    @objc private func appDidBecomeActive() {
        if isLoggedIn {
            print("🔧 应用重新激活，检查后台时间")

            if let backgroundTime = backgroundEnterTime {
                let backgroundDuration = Date().timeIntervalSince(backgroundTime)
                if backgroundDuration > backgroundTimeout {
                    print("🔧 后台时间超过5分钟，需要重新登录")
                    autoLogoutDueToBackgroundTimeout()
                    return
                }
            }
            
            print("🔧 重新开始不活跃计时器")
            resetInactivityTimer()
        }
    }
    
    @objc private func appDidEnterBackground() {
        print("🔧 应用已进入后台，记录进入后台时间")
        backgroundEnterTime = Date()
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        lastActivityTime = Date()

        if UIApplication.shared.applicationState == .active {
            inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
                self?.autoLogoutDueToInactivity()
            }
        }
    }
    
    private func autoLogoutDueToInactivity() {
        guard isLoggedIn else { return }
        
        print("由于长时间无操作，自动退出登录")
        logout()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("AutoLogoutDueToInactivity"),
            object: nil
        )
    }
    
    private func autoLogoutDueToBackgroundTimeout() {
        guard isLoggedIn else { return }
        
        print("由于后台时间过长，需要重新登录")
        logout()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("AutoLogoutDueToBackgroundTimeout"),
            object: nil
        )
    }

    func debugResetLogin() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userData")
        self.isLoggedIn = false
        self.authToken = nil
        self.currentUser = nil
        self.inactivityTimer?.invalidate()
        self.inactivityTimer = nil
        
        self.objectWillChange.send()
        
        print("🔧 调试：登录状态已重置")
    }
    
    func printDebugInfo() {
        print("=== 登录状态调试信息 ===")
        print("isLoggedIn: \(isLoggedIn)")
        print("authToken: \(authToken?.prefix(10) ?? "nil")...")
        print("currentUser: \(currentUser?.username ?? "nil")")
        print("currentUserType: \(currentUser?.userType.rawValue ?? "nil")")
        print("UserDefaults authToken: \(UserDefaults.standard.string(forKey: "authToken")?.prefix(10) ?? "nil")...")
        print("最后活动时间: \(lastActivityTime)")
        print("最后用户名: \(getLastUsername())")
        print("记住用户名: \(shouldRememberUsername())")
        print("注册账户数: \(getRegisteredAccountsCount())")
        print("认证失败次数: \(UserDefaults.standard.integer(forKey: "authFailedAttempts"))")
        print("订阅结束时间: \(getSubscriptionEndDate() ?? "无")")
        print("应用状态: \(UIApplication.shared.applicationState.rawValue)")
        print("=========================")
    }
    
    deinit {
        inactivityTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

struct User {
    let id: String
    let username: String
    let userType: AuthService.UserType
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    
    init(from dict: [String: Any]) {
        self.id = String(dict["user_id"] as? Int ?? 0)
        self.username = dict["username"] as? String ?? ""

        if let userTypeString = dict["user_type"] as? String,
           let userType = AuthService.UserType(rawValue: userTypeString) {
            self.userType = userType
        } else {
            self.userType = .free
        }

        var tempSubscriptionStart: Date? = nil
        var tempSubscriptionEnd: Date? = nil

        if let startString = dict["subscription_start"] as? String {
            tempSubscriptionStart = User.parseDate(from: startString)
            if tempSubscriptionStart == nil {
                print("🔧 无法解析订阅开始日期: \(startString)")
            }
        }

        if let endString = dict["subscription_end"] as? String {
            tempSubscriptionEnd = User.parseDate(from: endString)
            if tempSubscriptionEnd == nil {
                print("🔧 无法解析订阅结束日期: \(endString)")
            }
        }

        self.subscriptionStart = tempSubscriptionStart
        self.subscriptionEnd = tempSubscriptionEnd
        
        print("🔧 User 模型创建 - ID: \(self.id), 用户名: \(self.username), 类型: \(self.userType.rawValue), 订阅开始: \(self.subscriptionStart?.description ?? "nil"), 订阅结束: \(self.subscriptionEnd?.description ?? "nil")")
    }
    
    init(id: String, username: String, userType: AuthService.UserType, subscriptionStart: Date?, subscriptionEnd: Date?) {
        self.id = id
        self.username = username
        self.userType = userType
        self.subscriptionStart = subscriptionStart
        self.subscriptionEnd = subscriptionEnd
    }
    
    var isSubscribedAndActive: Bool {
        guard userType == .subscribed, let endDate = subscriptionEnd else {
            return false
        }
        return endDate > Date()
    }
    
    private static func parseDate(from string: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }

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
            }(),
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                return formatter
            }(),
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        return nil
    }
}
