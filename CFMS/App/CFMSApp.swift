import SwiftUI

@main
struct CFMSApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var fundService = FundService()
    
    init() {
        setupExceptionHandling()
        configureAppInfo()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(fundService)
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
}
