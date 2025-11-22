// CloudSyncView.swift
import SwiftUI

struct CloudSyncView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var cloudSyncManager = CloudSyncManager()
    @State private var showingUploadConfirmation = false
    @State private var showingDownloadConfirmation = false
    
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
        .onAppear {
            cloudSyncManager.checkDownloadPermissions(authService: authService)
        }
    }
}
