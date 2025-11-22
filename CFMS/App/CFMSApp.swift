// CFMSApp是SwiftUI应用程序的入口点，负责初始化核心服务、配置全局设置、处理异常和外部文件导入。
import SwiftUI
import UniformTypeIdentifiers

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
        debugSupportedDocumentTypes()
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

    private func debugSupportedDocumentTypes() {
        print("=== 支持的文档类型调试信息 ===")

        if let documentTypes = Bundle.main.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]] {
            print("CFBundleDocumentTypes 数量: \(documentTypes.count)")
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
                if let extensions = type["CFBundleTypeExtensions"] as? [String] {
                    print("  - 文件扩展名: \(extensions)")
                }
            }
        } else {
            print("CFMSApp: 未找到 CFBundleDocumentTypes 配置")
        }

        if let importedTypes = Bundle.main.infoDictionary?["UTImportedTypeDeclarations"] as? [[String: Any]] {
            print("UTImportedTypeDeclarations 数量: \(importedTypes.count)")
            for (index, type) in importedTypes.enumerated() {
                print("导入类型 \(index + 1):")
                if let identifier = type["UTTypeIdentifier"] as? String {
                    print("  - 类型标识符: \(identifier)")
                }
                if let description = type["UTTypeDescription"] as? String {
                    print("  - 描述: \(description)")
                }
            }
        } else {
            print("CFMSApp: 未找到 UTImportedTypeDeclarations 配置")
        }

        if let exportedTypes = Bundle.main.infoDictionary?["UTExportedTypeDeclarations"] as? [[String: Any]] {
            print("UTExportedTypeDeclarations 数量: \(exportedTypes.count)")
            for (index, type) in exportedTypes.enumerated() {
                print("导出类型 \(index + 1):")
                if let identifier = type["UTTypeIdentifier"] as? String {
                    print("  - 类型标识符: \(identifier)")
                }
                if let description = type["UTTypeDescription"] as? String {
                    print("  - 描述: \(description)")
                }
            }
        } else {
            print("CFMSApp: 未找到 UTExportedTypeDeclarations 配置")
        }
        
        print("=============================")
    }

    private func registerDocumentTypes() {
        print("CFMSApp: 注册文档类型...")
        

        print("CFMSApp: 应用支持打开以下文件类型:")
        print("CFMSApp: - CSV文件 (.csv)")
        print("CFMSApp: - 文本文件 (.txt)")
    }

    private func handleIncomingFile(url: URL) {
        print("CFMSApp: 收到文件URL: \(url)")
        print("CFMSApp: 文件路径: \(url.path)")
        print("CFMSApp: 文件扩展名: \(url.pathExtension)")
        print("CFMSApp: 文件名称: \(url.lastPathComponent)")

        let supportedExtensions = ["csv", "txt"]
        let fileExtension = url.pathExtension.lowercased()
        
        print("CFMSApp: 检查文件扩展名: \(fileExtension)")
        
        guard supportedExtensions.contains(fileExtension) else {
            print("CFMSApp: 不支持的文件类型: \(fileExtension)")
            showImportErrorAlert(message: "不支持的文件类型: \(fileExtension)")
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            print("CFMSApp: 无法获取文件安全访问权限")
            showImportErrorAlert(message: "无法访问文件")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        processImportedFile(url: url)
    }

    private func processImportedFile(url: URL) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "imported_\(Int(Date().timeIntervalSince1970)).csv"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        print("CFMSApp: 开始处理导入文件")
        print("CFMSApp: 源文件: \(url)")
        print("CFMSApp: 目标文件: \(destinationURL)")
        
        do {
            try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            DispatchQueue.main.async {
                self.importedFileURL = destinationURL
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
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showImportErrorAlert(message: String) {
        print("CFMSApp: 导入错误: \(message)")

        let content = UNMutableNotificationContent()
        content.title = "文件导入失败"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "importError", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
