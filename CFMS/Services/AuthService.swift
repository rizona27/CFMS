//后端认证模块
import Foundation
import Combine
import SwiftUI

class AuthService: ObservableObject {
    let baseURL = "https://cfms.crnas.uk:8315"
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var authToken: String?

    enum UserType: String {
        case free = "free"
        case subscribed = "subscribed"
        case vip = "vip"
    }

    private var inactivityTimer: Timer?
    private let inactivityTimeout: TimeInterval = 5 * 60 // 5分钟
    private var lastActivityTime: Date = Date()

    private let maxAuthAttempts = 3
    private let authLockoutDuration: TimeInterval = 10 * 60
    private let registerCooldownDuration: TimeInterval = 5 * 60
    
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
        
        if let lastRegisterTime = UserDefaults.standard.object(forKey: "lastRegisterTime") as? Date {
            let elapsedTime = Date().timeIntervalSince(lastRegisterTime)
            if elapsedTime < registerCooldownDuration {
                let remainingTime = registerCooldownDuration - elapsedTime
                return (false, remainingTime)
            }
        }
        return (true, nil)
    }
    
    func canLogin() -> (canLogin: Bool, remainingTime: TimeInterval?) {
        let authResult = canAuth()
        return (canLogin: authResult.canAuth, remainingTime: authResult.remainingTime)
    }
    
    // 修改：将这个方法改为 internal 而不是 private
    func canAuth() -> (canAuth: Bool, remainingTime: TimeInterval?) {
        let failedAttempts = UserDefaults.standard.integer(forKey: "authFailedAttempts")
        if let lockoutTime = UserDefaults.standard.object(forKey: "authLockoutTime") as? Date {
            let elapsedTime = Date().timeIntervalSince(lockoutTime)
            if elapsedTime < authLockoutDuration {
                let remainingTime = authLockoutDuration - elapsedTime
                return (false, remainingTime)
            } else {
                UserDefaults.standard.set(0, forKey: "authFailedAttempts")
                UserDefaults.standard.removeObject(forKey: "authLockoutTime")
            }
        }
        
        if failedAttempts >= maxAuthAttempts {
            UserDefaults.standard.set(Date(), forKey: "authLockoutTime")
            return (false, authLockoutDuration)
        }
        
        return (true, nil)
    }

    private func recordAuthFailure() {
        var failedAttempts = UserDefaults.standard.integer(forKey: "authFailedAttempts")
        failedAttempts += 1
        UserDefaults.standard.set(failedAttempts, forKey: "authFailedAttempts")
        
        print("🔧 认证失败次数: \(failedAttempts)")
        
        if failedAttempts >= maxAuthAttempts {
            UserDefaults.standard.set(Date(), forKey: "authLockoutTime")
            print("🔧 认证已被锁定，请10分钟后再试")
        }
    }

    private func recordRegisterTime() {
        UserDefaults.standard.set(Date(), forKey: "lastRegisterTime")
    }
    
    private func resetAuthFailure() {
        UserDefaults.standard.set(0, forKey: "authFailedAttempts")
        UserDefaults.standard.removeObject(forKey: "authLockoutTime")
    }

    func login(username: String, password: String, completion: @escaping (Bool, String) -> Void) {
        print("🔧 开始登录流程，用户名: \(username)")

        let loginCheck = canLogin()
        if !loginCheck.canLogin {
            if let remainingTime = loginCheck.remainingTime {
                let minutes = Int(ceil(remainingTime / 60))
                completion(false, "登录尝试次数过多，请\(minutes)分钟后再试")
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
                    print("🔧 登录响应: \(responseString)")
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            let token = json["token"] as? String ?? ""
                            
                            let userData = json["user_info"] as? [String: Any] ?? [:]
                            
                            print("🔧 登录成功，用户数据: \(userData)")
                            
                            self.saveLoginStatus(token: token, userData: userData)
                            
                            self.isLoggedIn = true
                            self.authToken = token
                            self.currentUser = User(from: userData)
                            self.resetInactivityTimer()
                            
                            self.resetAuthFailure()
                            
                            self.objectWillChange.send()
                            
                            print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil"), 类型: \(self.currentUser?.userType.rawValue ?? "unknown"), 订阅结束: \(self.currentUser?.subscriptionEnd?.description ?? "nil")")
                            
                            completion(true, json["message"] as? String ?? "登录成功")
                        } else {
                            self.recordAuthFailure()
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
                let minutes = Int(ceil(remainingTime / 60))
                completion(false, "注册过于频繁，请\(minutes)分钟后再试")
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
                            
                            self.recordRegisterTime()
                            self.resetAuthFailure()
                            
                            self.isLoggedIn = true
                            self.authToken = token
                            self.currentUser = User(from: userData)
                            self.resetInactivityTimer()
                            
                            self.objectWillChange.send()
                            
                            print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil"), 类型: \(self.currentUser?.userType.rawValue ?? "unknown")")
                            
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
        // 应用即将进入非活跃状态（最小化、锁屏等）
        print("🔧 应用即将进入后台，停止不活跃计时器")
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    @objc private func appDidBecomeActive() {
        // 应用重新激活
        if isLoggedIn {
            print("🔧 应用重新激活，重新开始不活跃计时器")
            resetInactivityTimer()
        }
    }
    
    @objc private func appDidEnterBackground() {
        // 应用已进入后台
        print("🔧 应用已进入后台，停止不活跃计时器")
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        lastActivityTime = Date()
        
        // 只在应用处于活跃状态时启动计时器
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
