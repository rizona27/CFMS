// CFMSApp是SwiftUI应用程序的入口点，负责初始化核心服务、配置全局设置、处理异常和外部文件导入。
import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication

@main
struct CFMSApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var fundService = FundService()
    @StateObject private var authService = AuthService()
    @State private var importedFileURL: URL?
    
    init() {
        setupExceptionHandling()
        configureAppInfo()
        printDocumentTypeSupport()
        checkRuntimeDocumentTypes()
        checkFaceIDAvailability()
        checkFileImportPermissions()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(fundService)
                .environmentObject(authService)
                .onOpenURL { url in
                    print("CFMSApp: 收到打开URL请求: \(url)")
                    handleIncomingFile(url: url)
                }
                .onAppear {
                    registerDocumentTypes()
                    requestNotificationPermission()
                }
        }
    }
    
    private func setupExceptionHandling() {
        NSSetUncaughtExceptionHandler { exception in
            print("CRASH: \(exception)")
            print("Stack Trace: \(exception.callStackSymbols)")
        }
    }

    private func configureAppInfo() {
        UserDefaults.standard.register(defaults: [
            "isPrivacyModeEnabled": true,
            "themeMode": "system",
            "selectedFundAPI": "eastmoney"
        ])
    }

    private func checkFileImportPermissions() {
        print("=== 文件导入权限检查 ===")
        
        // 检查文档类型支持
        let supportedTypes = [
            UTType.commaSeparatedText,
            UTType.plainText,
            UTType.text
        ]
        
        for type in supportedTypes {
            print("支持的类型: \(type.identifier)")
        }
        
        // 检查文件共享权限
        let fileSharingEnabled = Bundle.main.infoDictionary?["UIFileSharingEnabled"] as? Bool ?? false
        print("文件共享启用: \(fileSharingEnabled)")
        
        // 检查文档类型声明
        if let documentTypes = Bundle.main.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]] {
            print("已配置的文档类型数量: \(documentTypes.count)")
            for (index, type) in documentTypes.enumerated() {
                print("文档类型 \(index + 1):")
                if let typeName = type["CFBundleTypeName"] as? String {
                    print("  - 类型名称: \(typeName)")
                }
                if let role = type["CFBundleTypeRole"] as? String {
                    print("  - 角色: \(role)")
                }
                if let contentTypes = type["LSItemContentTypes"] as? [String] {
                    print("  - 内容类型: \(contentTypes)")
                }
            }
        } else {
            print("警告: 未配置CFBundleDocumentTypes")
        }
        
        print("=========================")
    }

    private func printDocumentTypeSupport() {
        print("CFMSApp: 检查文档类型支持...")

        if let csvType = UTType("public.comma-separated-values-text") {
            print("CFMSApp: CSV类型标识符: \(csvType.identifier)")
            print("CFMSApp: CSV类型标签: \(csvType.tags)")
        } else {
            print("CFMSApp: 无法创建CSV类型")
        }

        let textType = UTType.text
        print("CFMSApp: 文本类型标识符: \(textType.identifier)")

        if let plainTextType = UTType("public.plain-text") {
            print("CFMSApp: 纯文本类型标识符: \(plainTextType.identifier)")
        }
    }

    // 运行时文档类型检查
    private func checkRuntimeDocumentTypes() {
        print("=== 运行时文档类型检查 ===")
        
        // 检查系统已知的类型
        if let csvType = UTType("public.comma-separated-values-text") {
            print("系统支持 CSV 类型: \(csvType.identifier)")
        }
        
        if let textType = UTType("public.plain-text") {
            print("系统支持纯文本类型: \(textType.identifier)")
        }
        
        // 检查文件扩展名关联
        if let csvTypeByExt = UTType(filenameExtension: "csv") {
            print("CSV 扩展名关联类型: \(csvTypeByExt.identifier)")
        }
        
        if let txtTypeByExt = UTType(filenameExtension: "txt") {
            print("TXT 扩展名关联类型: \(txtTypeByExt.identifier)")
        }
        
        // 检查生物识别权限配置
        if let faceIDUsage = Bundle.main.infoDictionary?["NSFaceIDUsageDescription"] as? String {
            print("生物识别权限配置: \(faceIDUsage)")
        } else {
            print("警告: 未找到 NSFaceIDUsageDescription 配置")
        }
        
        print("=========================")
    }

    // 新增：检查 Face ID 可用性
    private func checkFaceIDAvailability() {
        print("=== Face ID 可用性检查 ===")
        
        let context = LAContext()
        var error: NSError?
        
        // 检查设备是否支持生物识别
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if context.biometryType == .faceID {
                print("设备支持 Face ID")
            } else if context.biometryType == .touchID {
                print("设备支持 Touch ID")
            } else {
                print("设备支持其他生物识别方式")
            }
        } else {
            print("设备不支持生物识别或未设置: \(error?.localizedDescription ?? "未知错误")")
        }
        
        // 再次确认 Info.plist 配置
        if Bundle.main.infoDictionary?["NSFaceIDUsageDescription"] == nil {
            print("严重错误: Info.plist 中缺少 NSFaceIDUsageDescription")
        } else {
            print("Info.plist 中已配置 NSFaceIDUsageDescription")
        }
        
        print("=========================")
    }

    private func registerDocumentTypes() {
        print("CFMSApp: 注册文档类型...")
        
        // 强制注册文档类型
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            let csvType = UTType(filenameExtension: "csv")!
            let textType = UTType(filenameExtension: "txt")!
            
            print("CFMSApp: 注册文档类型 - CSV: \(csvType), Text: \(textType)")
            print("CFMSApp: Bundle Identifier: \(bundleIdentifier)")
        }
        
        // 检查实际可处理的类型
        let supportedTypes = [
            UTType.commaSeparatedText,
            UTType.plainText,
            UTType.text
        ].compactMap { $0 }
        
        print("CFMSApp: 实际可处理的UTTypes: \(supportedTypes.map { $0.identifier })")
        
        print("CFMSApp: 应用支持打开以下文件类型:")
        print("CFMSApp: - CSV文件 (.csv)")
        print("CFMSApp: - 文本文件 (.txt)")
    }

    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("CFMSApp: 通知权限请求错误: \(error)")
            } else {
                print("CFMSApp: 通知权限 granted: \(granted)")
            }
        }
    }

    private func handleIncomingFile(url: URL) {
        print("CFMSApp: 收到文件URL: \(url)")
        print("CFMSApp: 文件路径: \(url.path)")
        print("CFMSApp: 文件扩展名: \(url.pathExtension)")
        print("CFMSApp: 文件名称: \(url.lastPathComponent)")

        // 新增：应用沙盒权限检查
        print("CFMSApp: 应用沙盒权限检查...")
        let isSandboxed = Bundle.main.appStoreReceiptURL?.path.contains("CoreSimulator") == false
        print("CFMSApp: 应用沙盒状态: \(isSandboxed ? "沙盒环境" : "开发环境")")
        
        // 检查文件访问权限
        let canAccess = FileManager.default.isReadableFile(atPath: url.path)
        print("CFMSApp: 文件可访问: \(canAccess)")

        let supportedExtensions = ["csv", "txt"]
        let fileExtension = url.pathExtension.lowercased()
        
        print("CFMSApp: 检查文件扩展名: \(fileExtension)")
        
        // 放宽检查：如果配置不生效，直接处理支持的文件扩展名
        guard supportedExtensions.contains(fileExtension) else {
            print("CFMSApp: 不支持的文件类型: \(fileExtension)")
            showImportErrorAlert(message: "不支持的文件类型: \(fileExtension)")
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            print("CFMSApp: 无法获取文件安全访问权限")
            showImportErrorAlert(message: "无法访问文件，请检查文件权限")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
            print("CFMSApp: 已释放安全访问权限")
        }
        
        // 检查原始文件的可访问性
        let fileManager = FileManager.default
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: url.path) else {
            print("CFMSApp: 原始文件不存在")
            showImportErrorAlert(message: "文件不存在")
            return
        }
        
        // 检查文件可读性
        guard fileManager.isReadableFile(atPath: url.path) else {
            print("CFMSApp: 原始文件不可读")
            showImportErrorAlert(message: "文件不可读，请检查权限")
            return
        }
        
        // 如果检查通过，处理文件
        processImportedFile(url: url)
    }

    private func processImportedFile(url: URL) {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("CFMSApp: 无法获取Documents目录")
            showImportErrorAlert(message: "无法访问应用存储空间")
            return
        }
        
        let fileName = "imported_\(Int(Date().timeIntervalSince1970)).\(url.pathExtension)"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        print("CFMSApp: 开始处理导入文件")
        print("CFMSApp: 源文件: \(url)")
        print("CFMSApp: 目标文件: \(destinationURL)")
        
        do {
            // 确保目标目录存在
            try fileManager.createDirectory(at: documentsPath, withIntermediateDirectories: true)
            
            // 如果目标文件已存在，先删除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // 复制文件
            try fileManager.copyItem(at: url, to: destinationURL)
            
            // 验证复制后的文件
            guard fileManager.fileExists(atPath: destinationURL.path) else {
                print("CFMSApp: 复制后文件不存在")
                showImportErrorAlert(message: "文件复制失败")
                return
            }
            
            guard fileManager.isReadableFile(atPath: destinationURL.path) else {
                print("CFMSApp: 复制后文件不可读")
                showImportErrorAlert(message: "复制文件不可读")
                return
            }
            
            // 获取复制后文件大小
            let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            print("CFMSApp: 复制后文件大小: \(fileSize) 字节")
            
            if fileSize == 0 {
                print("CFMSApp: 复制后文件为空")
                showImportErrorAlert(message: "文件内容为空")
                return
            }
            
            DispatchQueue.main.async {
                print("CFMSApp: 发送文件导入通知: \(destinationURL)")
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("FileImportedFromShare"),
                    object: nil,
                    userInfo: ["fileURL": destinationURL]
                )
                
                self.showImportSuccessAlert()
            }
            
            print("CFMSApp: 文件导入成功: \(destinationURL)")
            
        } catch {
            print("CFMSApp: 文件复制错误: \(error)")
            showImportErrorAlert(message: "文件导入失败: \(error.localizedDescription)")
        }
    }

    private func showImportSuccessAlert() {
        print("CFMSApp: 文件导入成功！")

        let content = UNMutableNotificationContent()
        content.title = "文件导入成功"
        content.body = "CSV文件已成功导入，正在处理数据..."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "importSuccess", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("CFMSApp: 发送成功通知失败: \(error)")
            }
        }
    }
    
    private func showImportErrorAlert(message: String) {
        print("CFMSApp: 导入错误: \(message)")

        let content = UNMutableNotificationContent()
        content.title = "文件导入失败"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "importError", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("CFMSApp: 发送错误通知失败: \(error)")
            }
        }
    }
}
