import Foundation
import Combine
import SwiftUI

class AuthService: ObservableObject {
    let baseURL = "https://cfms.crnas.uk:8315"
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var authToken: String?
    
    // 用户类型常量
    enum UserType: String {
        case free = "free"           // 基础用户
        case subscribed = "subscribed" // 试用用户
        case vip = "vip"             // 尊享用户
    }
    
    // 超时管理
    private var inactivityTimer: Timer?
    private let inactivityTimeout: TimeInterval = 5 * 60 // 5分钟
    private var lastActivityTime: Date = Date()
    
    // 登录限制管理
    private let maxLoginAttempts = 3
    private let loginLockoutDuration: TimeInterval = 10 * 60 // 10分钟
    private let registerCooldownDuration: TimeInterval = 5 * 60 // 5分钟
    
    init() {
        print("🔧 AuthService 初始化")
        checkLoginStatus()
        setupInactivityMonitoring()
    }
    
    // MARK: - 新增功能：获取体验用户到期时间
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
    
    // MARK: - 新增功能：检查订阅状态
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
    
    // 检查是否可以注册
    func canRegister() -> (canRegister: Bool, remainingTime: TimeInterval?) {
        if let lastRegisterTime = UserDefaults.standard.object(forKey: "lastRegisterTime") as? Date {
            let elapsedTime = Date().timeIntervalSince(lastRegisterTime)
            if elapsedTime < registerCooldownDuration {
                let remainingTime = registerCooldownDuration - elapsedTime
                return (false, remainingTime)
            }
        }
        return (true, nil)
    }
    
    // 检查是否可以登录
    func canLogin() -> (canLogin: Bool, remainingTime: TimeInterval?) {
        // 检查登录尝试次数
        let failedAttempts = UserDefaults.standard.integer(forKey: "loginFailedAttempts")
        if let lockoutTime = UserDefaults.standard.object(forKey: "loginLockoutTime") as? Date {
            let elapsedTime = Date().timeIntervalSince(lockoutTime)
            if elapsedTime < loginLockoutDuration {
                let remainingTime = loginLockoutDuration - elapsedTime
                return (false, remainingTime)
            } else {
                // 锁定时间已过，重置计数器
                UserDefaults.standard.set(0, forKey: "loginFailedAttempts")
                UserDefaults.standard.removeObject(forKey: "loginLockoutTime")
            }
        }
        
        if failedAttempts >= maxLoginAttempts {
            // 设置锁定时间
            UserDefaults.standard.set(Date(), forKey: "loginLockoutTime")
            return (false, loginLockoutDuration)
        }
        
        return (true, nil)
    }
    
    // 记录登录失败
    private func recordLoginFailure() {
        var failedAttempts = UserDefaults.standard.integer(forKey: "loginFailedAttempts")
        failedAttempts += 1
        UserDefaults.standard.set(failedAttempts, forKey: "loginFailedAttempts")
        
        print("🔧 登录失败次数: \(failedAttempts)")
        
        if failedAttempts >= maxLoginAttempts {
            UserDefaults.standard.set(Date(), forKey: "loginLockoutTime")
            print("🔧 登录已被锁定，请10分钟后再试")
        }
    }
    
    // 记录注册时间
    private func recordRegisterTime() {
        UserDefaults.standard.set(Date(), forKey: "lastRegisterTime")
    }
    
    // 重置登录失败计数（登录成功时调用）
    private func resetLoginFailure() {
        UserDefaults.standard.set(0, forKey: "loginFailedAttempts")
        UserDefaults.standard.removeObject(forKey: "loginLockoutTime")
    }
    
    // 用户登录
    func login(username: String, password: String, completion: @escaping (Bool, String) -> Void) {
        print("🔧 开始登录流程，用户名: \(username)")
        
        // 检查登录限制
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
                    self.recordLoginFailure()
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.recordLoginFailure()
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
                            
                            self.resetLoginFailure()
                            
                            self.objectWillChange.send()
                            
                            print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil"), 类型: \(self.currentUser?.userType.rawValue ?? "unknown"), 订阅结束: \(self.currentUser?.subscriptionEnd?.description ?? "nil")")
                            
                            completion(true, json["message"] as? String ?? "登录成功")
                        } else {
                            self.recordLoginFailure()
                            let message = json["message"] as? String ?? json["error"] as? String ?? "登录失败"
                            completion(false, message)
                        }
                    } else {
                        self.recordLoginFailure()
                        completion(false, "响应格式错误")
                    }
                } catch {
                    self.recordLoginFailure()
                    completion(false, "数据解析错误: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // 用户注册
    func register(username: String, password: String, confirmPassword: String, completion: @escaping (Bool, String) -> Void) {
        print("🔧 开始注册流程，用户名: \(username)")
        
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
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
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
                            
                            self.isLoggedIn = true
                            self.authToken = token
                            self.currentUser = User(from: userData)
                            self.resetInactivityTimer()
                            
                            self.objectWillChange.send()
                            
                            print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil"), 类型: \(self.currentUser?.userType.rawValue ?? "unknown")")
                            
                            completion(true, json["message"] as? String ?? "注册成功")
                        } else {
                            let message = json["message"] as? String ?? json["error"] as? String ?? "注册失败"
                            completion(false, message)
                        }
                    } else {
                        completion(false, "响应格式错误")
                    }
                } catch {
                    completion(false, "数据解析错误: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // 退出登录
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
    
    // 保存登录状态
    private func saveLoginStatus(token: String, userData: [String: Any]) {
        UserDefaults.standard.set(token, forKey: "authToken")
        if let userJsonData = try? JSONSerialization.data(withJSONObject: userData) {
            UserDefaults.standard.set(userJsonData, forKey: "userData")
        }
        print("🔧 登录状态已保存到 UserDefaults")
    }
    
    // 检查登录状态
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
    
    // MARK: - 超时管理
    private func setupInactivityMonitoring() {
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
    
    @objc private func appDidBecomeActive() {
        if isLoggedIn {
            resetInactivityTimer()
        }
    }
    
    @objc private func appDidEnterBackground() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        lastActivityTime = Date()
        
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            self?.autoLogoutDueToInactivity()
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
    
    // MARK: - 开发调试方法
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
        print("=========================")
    }
    
    deinit {
        inactivityTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// 用户模型
struct User {
    let id: String
    let username: String
    let userType: AuthService.UserType
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    
    init(from dict: [String: Any]) {
        self.id = String(dict["user_id"] as? Int ?? 0)
        self.username = dict["username"] as? String ?? ""
        
        // 解析用户类型，确保是三种类型之一
        if let userTypeString = dict["user_type"] as? String,
           let userType = AuthService.UserType(rawValue: userTypeString) {
            self.userType = userType
        } else {
            // 默认为基础用户
            self.userType = .free
        }
        
        // 修复：先初始化所有属性，然后再解析日期
        var tempSubscriptionStart: Date? = nil
        var tempSubscriptionEnd: Date? = nil
        
        // 解析订阅开始日期
        if let startString = dict["subscription_start"] as? String {
            tempSubscriptionStart = User.parseDate(from: startString) // 👈 修复点: 调用静态方法
            if tempSubscriptionStart == nil {
                print("🔧 无法解析订阅开始日期: \(startString)")
            }
        }
        
        // 解析订阅结束日期
        if let endString = dict["subscription_end"] as? String {
            tempSubscriptionEnd = User.parseDate(from: endString) // 👈 修复点: 调用静态方法
            if tempSubscriptionEnd == nil {
                print("🔧 无法解析订阅结束日期: \(endString)")
            }
        }
        
        // 现在赋值给常量属性
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
    
    // 辅助方法：检查是否为试用用户且订阅未过期
    var isSubscribedAndActive: Bool {
        guard userType == .subscribed, let endDate = subscriptionEnd else {
            return false
        }
        return endDate > Date()
    }
    
    // 辅助方法：解析日期字符串
    // **已修改为 static func，解决初始化错误**
    private static func parseDate(from string: String) -> Date? {
        // 先尝试 ISO8601DateFormatter
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }
        
        // 如果 ISO8601 失败，尝试其他格式
        let formatters = [
            // ISO8601 格式（带时区）
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return formatter
            }(),
            // 简单的日期格式
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            // 包含时间的格式
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            // 不带毫秒的ISO8601格式
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                return formatter
            }(),
            // 不带时区的ISO8601格式
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
