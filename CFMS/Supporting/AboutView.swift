//关于卡片模块
import SwiftUI
struct UpdateLog: Identifiable {
    let id = UUID()
    let version: String
    let description: String
}

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentScrollIndex = 0
    @State private var timer: Timer?
    
    private let updateLogs: [UpdateLog] = [
        UpdateLog(version: "Version 1.0.0", description: "MMP项目构建。"),
        UpdateLog(version: "Version 2.0.0", description: "项目重构CFMS。\n重做UI界面。"),
        UpdateLog(version: "Version 2.1.0", description: "编辑持仓页面完善客户号显示搜索。"),
        UpdateLog(version: "Version 2.2.0", description: "增加自定义导航栏。\n添加iOS15版本兼容。"),
        UpdateLog(version: "Version 2.3.0", description: "后端构建。\n新增用户分层、云端备份、生物登录模块。"),
        UpdateLog(version: "Version X.", description: "To be continued...")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("一基暴富")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "FFD700"))
                        Text("Version: 2.3.7      By: rizona.cn@gmail.com")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("更新日志：")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)

                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(updateLogs.enumerated()), id: \.element.id) { index, log in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(log.version)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            Text(log.description)
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                                .lineSpacing(4)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .id(index)
                                    }
                                }
                                .padding(4)
                            }
                            .frame(height: 200)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onAppear {
                                startAutoScroll(proxy: proxy)
                            }
                            .onDisappear {
                                stopAutoScroll()
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("功能介绍")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                            .padding(.bottom, 5)

                        Text("跟踪管理多客户基金持仓，提供最新净值查询、收益统计等功能。")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("主要包括：")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.top, 10)

                        BulletPointView(text: "数据自动化：自动更新净值数据。")
                            .foregroundColor(Color(hex: "3498DB"))
                        BulletPointView(text: "数据持久化：本地保存客户数据。")
                            .foregroundColor(Color(hex: "2ECC71"))
                        BulletPointView(text: "客户多重管理：分组查看管理持仓。")
                            .foregroundColor(Color(hex: "E74C3C"))
                        BulletPointView(text: "报告一键生成：模板总结持仓收益。")
                            .foregroundColor(Color(hex: "F39C12"))
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("朕知道了") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startAutoScroll(proxy: ScrollViewProxy) {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                currentScrollIndex = (currentScrollIndex + 1) % updateLogs.count
                proxy.scrollTo(currentScrollIndex, anchor: .top)
            }
        }
    }
    
    private func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
    }
}

struct BulletPointView: View {
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.accentColor)
                .padding(.top, 6)
            Text(text)
        }
    }
}
