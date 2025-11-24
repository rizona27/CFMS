// CloudSyncView.swift
import SwiftUI
import UniformTypeIdentifiers

struct CloudSyncView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var fundService: FundService
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var cloudSyncManager = CloudSyncManager()
    @State private var showingUploadConfirmation = false
    @State private var showingDownloadConfirmation = false
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var showingImportConfirmation = false
    @State private var pendingImportURL: URL?
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        ThemedBackButton {
                            dismiss()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    VStack(spacing: 16) {
                        CustomCardView(
                            title: "上传到云端",
                            description: "将本地持仓数据备份到云端服务器",
                            imageName: "icloud.and.arrow.up.fill",
                            backgroundColor: Color.green.opacity(0.1),
                            contentForegroundColor: .green,
                            action: {
                                if dataManager.holdings.isEmpty {
                                    cloudSyncManager.setAlertMessage("本地没有持仓数据可上传")
                                } else {
                                    showingUploadConfirmation = true
                                }
                            }
                        ) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("本地持仓数量: \(dataManager.holdings.count)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.8))
                                
                                Text("云端数据将被覆盖")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity)

                        CustomCardView(
                            title: "从云端下载",
                            description: "将云端持仓数据同步到本地",
                            imageName: "arrow.down.circle.fill",
                            backgroundColor: Color.orange.opacity(0.1),
                            contentForegroundColor: .orange,
                            action: {
                                showingDownloadConfirmation = true
                            }
                        ) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("本地数据将被覆盖")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange.opacity(0.8))
                                
                                Text("此操作不可撤销")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // 文件导入导出卡片 - 暂时隐藏
                    /*
                    VStack(spacing: 16) {
                        CustomCardView(
                            title: "导入CSV文件",
                            description: "从CSV文件导入持仓数据",
                            imageName: "square.and.arrow.down.fill",
                            backgroundColor: Color.blue.opacity(0.1),
                            contentForegroundColor: .blue,
                            action: {
                                isImporting = true
                            }
                        ) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("支持多种CSV格式")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                Text("自动识别客户、基金、金额等信息")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity)

                        CustomCardView(
                            title: "导出CSV文件",
                            description: "导出持仓数据到CSV文件",
                            imageName: "square.and.arrow.up.fill",
                            backgroundColor: Color.purple.opacity(0.1),
                            contentForegroundColor: .purple,
                            action: {
                                exportHoldingsToCSV()
                            }
                        ) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("导出持仓数量: \(dataManager.holdings.count)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple.opacity(0.8))
                                
                                Text("标准CSV格式，兼容Excel")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    */
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            if cloudSyncManager.isUploading || cloudSyncManager.isDownloading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Text(cloudSyncManager.syncMessage)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
        .navigationBarHidden(true)
        .alert("确认上传", isPresented: $showingUploadConfirmation) {
            Button("取消", role: .cancel) { }
            Button("上传", role: .none) {
                guard authService.isLoggedIn else {
                    cloudSyncManager.setAlertMessage("请先登录账户")
                    return
                }

                guard cloudSyncManager.isNetworkAvailable else {
                    cloudSyncManager.setAlertMessage("网络连接不可用，请检查网络设置")
                    return
                }
                
                cloudSyncManager.uploadHoldingsToCloud(authService: authService, dataManager: dataManager)
            }
        } message: {
            Text("这将把 \(dataManager.holdings.count) 条本地持仓记录上传到云端，如有重复数据将被覆盖。")
        }
        .alert("确认下载", isPresented: $showingDownloadConfirmation) {
            Button("取消", role: .cancel) { }
            Button("下载", role: .destructive) {
                guard authService.isLoggedIn else {
                    cloudSyncManager.setAlertMessage("请先登录账户")
                    return
                }

                guard cloudSyncManager.isNetworkAvailable else {
                    cloudSyncManager.setAlertMessage("网络连接不可用，请检查网络设置")
                    return
                }

                guard cloudSyncManager.hasDownloadPermission else {
                    cloudSyncManager.setAlertMessage("没有下载权限，请联系管理员或确认订阅状态")
                    return
                }
                
                cloudSyncManager.downloadHoldingsFromCloud(authService: authService, dataManager: dataManager)
            }
        } message: {
            Text("这将从云端下载持仓数据并覆盖本地所有持仓记录，此操作不可撤销。")
        }
        .alert("同步提示", isPresented: $cloudSyncManager.showSyncAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(cloudSyncManager.syncAlertMessage)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleFileImport(result: result)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: dataManager.csvExportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: dataManager.generateExportFilename()
        ) { result in
            Task {
                await handleFileExport(result: result)
            }
        }
        .alert("导入CSV文件", isPresented: $showingImportConfirmation) {
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
            Button("导入", role: .none) {
                if let url = pendingImportURL {
                    Task {
                        await dataManager.processImportedFile(url: url)
                    }
                }
                pendingImportURL = nil
            }
        } message: {
            Text("是否要导入从其他应用分享的CSV文件？")
        }
        .onAppear {
            cloudSyncManager.checkDownloadPermissions(authService: authService)

            NotificationCenter.default.addObserver(forName: NSNotification.Name("FileImportedFromShare"), object: nil, queue: .main) { notification in
                if let fileURL = notification.userInfo?["fileURL"] as? URL {
                    pendingImportURL = fileURL
                    showingImportConfirmation = true
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FileImportedFromShare"), object: nil)
        }
        .toast(message: dataManager.toastMessage, isShowing: $dataManager.showToast)
    }

    private func handleFileImport(result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            await dataManager.processImportedFile(url: url)
        } catch {
            await fundService.addLog("导入失败: \(error.localizedDescription)", type: .error)
        }
    }

    private func handleFileExport(result: Result<URL, Error>) async {
        switch result {
        case .success(let url):
            await fundService.addLog("导出成功: \(url.lastPathComponent)", type: .success)
        case .failure(let error):
            await fundService.addLog("导出失败: \(error.localizedDescription)", type: .error)
        }
    }

    private func exportHoldingsToCSV() {
        if let document = dataManager.exportHoldingsToCSV() {
            dataManager.csvExportDocument = document
            isExporting = true
        }
    }
}
