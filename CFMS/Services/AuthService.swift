import Foundation
import Combine
import SwiftUI

class AuthService: ObservableObject {
    let baseURL = "https://cfms.crnas.uk:8315"  // 改为 internal 访问级别
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var authToken: String?
    
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
                            
                            // 修复1: 使用正确的键名 "user_info" 而不是 "user"
                            let userData = json["user_info"] as? [String: Any] ?? [:]
                            
                            print("🔧 登录成功，用户数据: \(userData)")
                            
                            self.saveLoginStatus(token: token, userData: userData)
                            
                            // 确保在主线程更新 @Published 属性
                            self.isLoggedIn = true
                            self.authToken = token
                            
                            // 修复2: 传递正确的用户数据
                            self.currentUser = User(from: userData)
                            self.resetInactivityTimer()
                            
                            // 重置登录失败计数
                            self.resetLoginFailure()
                            
                            // 强制发送对象变更通知
                            self.objectWillChange.send()
                            
                            print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil")")
                            
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
        
        // 检查注册限制
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
                            
                            // 修复3: 注册也使用正确的键名 "user_info"
                            let userData = json["user_info"] as? [String: Any] ?? [:]
                            
                            print("🔧 注册成功，用户数据: \(userData)")
                            
                            self.saveLoginStatus(token: token, userData: userData)
                            
                            // 记录注册时间
                            self.recordRegisterTime()
                            
                            // 确保在主线程更新 @Published 属性
                            self.isLoggedIn = true
                            self.authToken = token
                            self.currentUser = User(from: userData)
                            self.resetInactivityTimer()
                            
                            // 强制发送对象变更通知
                            self.objectWillChange.send()
                            
                            print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil")")
                            
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
        
        // 确保在主线程更新 @Published 属性
        self.isLoggedIn = false
        self.authToken = nil
        self.currentUser = nil
        
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        
        // 强制发送对象变更通知
        self.objectWillChange.send()
        
        print("🔧 AuthService 状态更新完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil")")
        
        // 发送退出登录通知
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
            
            // 强制发送对象变更通知
            self.objectWillChange.send()
            
            self.resetInactivityTimer()
            
            print("🔧 登录状态恢复完成 - 已登录: \(self.isLoggedIn), 用户: \(self.currentUser?.username ?? "nil")")
        } else {
            print("🔧 没有找到保存的登录信息")
        }
    }
    
    // MARK: - 超时管理
    private func setupInactivityMonitoring() {
        // 监听应用状态变化
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
        
        // 发送通知，可以在UI上显示提示
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
        
        // 强制发送对象变更通知
        self.objectWillChange.send()
        
        print("🔧 调试：登录状态已重置")
    }
    
    func printDebugInfo() {
        print("=== 登录状态调试信息 ===")
        print("isLoggedIn: \(isLoggedIn)")
        print("authToken: \(authToken?.prefix(10) ?? "nil")...")
        print("currentUser: \(currentUser?.username ?? "nil")")
        print("UserDefaults authToken: \(UserDefaults.standard.string(forKey: "authToken")?.prefix(10) ?? "nil")...")
        print("最后活动时间: \(lastActivityTime)")
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
    let userType: String
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    
    init(from dict: [String: Any]) {
        self.id = String(dict["user_id"] as? Int ?? 0)
        self.username = dict["username"] as? String ?? ""
        self.userType = dict["user_type"] as? String ?? "free"
        
        // 处理订阅开始时间
        if let startString = dict["subscription_start"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.subscriptionStart = formatter.date(from: startString)
        } else {
            self.subscriptionStart = nil
        }
        
        // 处理订阅结束时间
        if let endString = dict["subscription_end"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.subscriptionEnd = formatter.date(from: endString)
        } else {
            self.subscriptionEnd = nil
        }
        
        print("🔧 User 模型创建 - ID: \(self.id), 用户名: \(self.username), 类型: \(self.userType), 订阅开始: \(self.subscriptionStart?.description ?? "nil"), 订阅结束: \(self.subscriptionEnd?.description ?? "nil")")
    }
    
    // 新增初始化方法用于更新用户信息
    init(id: String, username: String, userType: String, subscriptionStart: Date?, subscriptionEnd: Date?) {
        self.id = id
        self.username = username
        self.userType = userType
        self.subscriptionStart = subscriptionStart
        self.subscriptionEnd = subscriptionEnd
    }
}
