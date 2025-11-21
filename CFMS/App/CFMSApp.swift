// CFMSApp是SwiftUI应用程序的入口点，负责初始化核心服务、配置全局设置、处理异常和外部文件导入。
import SwiftUI
@main
struct CFMSApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var fundService = FundService()
    @StateObject private var authService = AuthService()
    @State private var importedFileURL: URL?
    
    init() {
        setupExceptionHandling()
        configureAppInfo()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(fundService)
                .environmentObject(authService)
                .onOpenURL { url in
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

    private func registerDocumentTypes() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let url = URL(string: "documenttypes://reload") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    private func handleIncomingFile(url: URL) {
        print("收到文件URL: \(url)")
        guard url.pathExtension.lowercased() == "csv" else {
            print("不支持的文件类型: \(url.pathExtension)")
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            print("无法获取文件安全访问权限")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "imported_\(Date().timeIntervalSince1970).csv"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            DispatchQueue.main.async {
                self.importedFileURL = destinationURL
                print("发送文件导入通知: \(destinationURL)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("FileImportedFromShare"),
                    object: nil,
                    userInfo: ["fileURL": destinationURL]
                )
            }
            
            print("文件导入成功: \(destinationURL)")
        } catch {
            print("文件复制错误: \(error)")
        }
    }
}
