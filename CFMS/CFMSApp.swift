//
//  CFMSApp.swift
//  CFMS
//
//  Created by 倪志浩 on 2025/10/27.
//

import SwiftUI

@main
struct CFMSApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var fundService = FundService()
    
    init() {
        // 设置未捕获异常处理
        setupExceptionHandling()
        
        // 配置应用信息
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
        // 设置用户默认值
        UserDefaults.standard.register(defaults: [
            "isPrivacyModeEnabled": true,
            "themeMode": "system",
            "selectedFundAPI": "eastmoney"
        ])
    }
}
