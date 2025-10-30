import SwiftUI

struct ClientGroupForManagement: Identifiable {
    let id: String
    let clientName: String
    var holdings: [FundHolding]
}

struct ManageHoldingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedHolding: FundHolding? = nil
    @State private var isShowingRenameAlert: Bool = false
    @State private var clientToRename: ClientGroupForManagement? = nil
    @State private var newClientName: String = ""
    @State private var isShowingDeleteAlert: Bool = false
    @State private var clientToDelete: ClientGroupForManagement? = nil
    @State private var expandedClientCodes: Set<String> = []
    @State private var refreshID = UUID()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearchExpanded: Bool = false

    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled: Bool = false

    // 返回按钮样式定义
    private var backButton: some View {
        GradientButton(
            icon: "chevron.backward.circle",
            action: { dismiss() },
            colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]
        )
    }

    private var groupedHoldings: [ClientGroupForManagement] {
        let groupedDictionary = Dictionary(grouping: dataManager.holdings) { holding in
            holding.clientName
        }

        var clientGroups: [ClientGroupForManagement] = groupedDictionary.map { (clientName, holdings) in
            return ClientGroupForManagement(id: clientName, clientName: clientName, holdings: holdings)
        }

        clientGroups.sort { $0.clientName < $1.clientName }
        
        return clientGroups
    }

    private var filteredClientGroups: [ClientGroupForManagement] {
        if searchText.isEmpty {
            return groupedHoldings
        } else {
            return groupedHoldings.filter { group in
                group.clientName.localizedCaseInsensitiveContains(searchText) ||
                group.holdings.contains { holding in
                    holding.fundName.localizedCaseInsensitiveContains(searchText) ||
                    holding.fundCode.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }

    private var areAnyCardsExpanded: Bool {
        !expandedClientCodes.isEmpty
    }

    private func toggleAllCards() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if areAnyCardsExpanded {
                expandedClientCodes.removeAll()
            } else {
                expandedClientCodes = Set(filteredClientGroups.map { $0.id })
            }
        }
    }

    private func performSearch(with text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                searchText = text
            }
        }
    }

    private var headerContent: some View {
        VStack(spacing: 0) {
            HStack {
                // 使用定义好的返回按钮
                backButton
                
                GradientButton(
                    icon: areAnyCardsExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical",
                    action: toggleAllCards,
                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")]
                )

                GradientButton(
                    icon: isSearchExpanded ? "magnifyingglass.circle.fill" : "magnifyingglass.circle",
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSearchExpanded.toggle()
                        }
                    },
                    colors: [Color(hex: "f093fb"), Color(hex: "f5576c")]
                )
                
                Spacer()
                
                if !dataManager.holdings.isEmpty {
                    Text("客户数: \(groupedHoldings.count)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            
            if isSearchExpanded && !dataManager.holdings.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("输入客户名、基金代码、基金名称...", text: Binding(
                        get: { searchText },
                        set: { newValue in
                            searchText = newValue
                            performSearch(with: newValue)
                        }
                    ))
                        .textFieldStyle(PlainTextFieldStyle())
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    headerContent
                
                    if dataManager.holdings.isEmpty {
                        EmptyStateView(
                            icon: "person.2.slash",
                            title: "当前没有持仓数据",
                            description: "请先导入持仓数据",
                            action: nil
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 2)
                    } else if filteredClientGroups.isEmpty && !searchText.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "未找到符合条件的客户",
                            description: "请尝试其他搜索关键词",
                            action: nil
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 2)
                    } else {
                        // 将所有客户组包裹在一个统一的框体内
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredClientGroups) { clientGroup in
                                    clientGroupItemView(clientGroup: clientGroup)
                                        .id("\(clientGroup.id)_\(clientGroup.holdings.hashValue)")
                                }
                            }
                            .padding(16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 2)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .navigationBarHidden(true)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isSearchExpanded)
        .id(refreshID)
        .sheet(item: $selectedHolding) { holdingToEdit in
            EditHoldingView(holding: holdingToEdit) { updatedHolding in
                do {
                    try dataManager.updateHolding(updatedHolding)
                    Task { @MainActor in
                        let fetchedInfo = await fundService.fetchFundInfo(code: updatedHolding.fundCode)
                        var refreshedHolding = updatedHolding
                        refreshedHolding.fundName = fetchedInfo.fundName
                        refreshedHolding.currentNav = fetchedInfo.currentNav
                        refreshedHolding.navDate = fetchedInfo.navDate
                        refreshedHolding.isValid = fetchedInfo.isValid
                        do {
                            try dataManager.updateHolding(refreshedHolding)
                        } catch {
                            Task {
                                await fundService.addLog("更新持仓失败: \(error.localizedDescription)", type: .error)
                            }
                        }
                    }
                } catch {
                    Task {
                        await fundService.addLog("更新持仓失败: \(error.localizedDescription)", type: .error)
                    }
                }
            }
            .environmentObject(dataManager)
            .environmentObject(fundService)
        }
        .alert("修改客户姓名", isPresented: $isShowingRenameAlert) {
            TextField("新客户姓名", text: $newClientName)
            Button("确定", action: {
                Task {
                    await renameClient()
                }
            })
            Button("取消", role: .cancel) {
                newClientName = ""
                clientToRename = nil
            }
        } message: {
            if let client = clientToRename {
                Text("将客户 \"\(client.clientName)\" 下的所有持仓姓名修改为:")
            } else {
                Text("无法找到要修改的客户。")
            }
        }
        .alert("删除客户持仓", isPresented: $isShowingDeleteAlert) {
            Button("确定删除", role: .destructive, action: {
                Task {
                    await confirmDeleteClientHoldings()
                }
            })
            Button("取消", role: .cancel) {
                clientToDelete = nil
            }
        } message: {
            if let client = clientToDelete {
                Text("您确定要删除客户 \"\(client.clientName)\" 名下的所有基金持仓吗？此操作无法撤销。")
            } else {
                Text("无法找到要删除的客户。")
            }
        }
        .onDisappear {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearchExpanded = false
            }
        }
    }
    
    // MARK: - clientGroupItemView (已修改)
    private func clientGroupItemView(clientGroup: ClientGroupForManagement) -> some View {
        let baseColor = clientGroup.clientName.morandiColor()
        let isExpanded = expandedClientCodes.contains(clientGroup.id)
        let displayClientName = isPrivacyModeEnabled ? processClientName(clientGroup.clientName) : clientGroup.clientName
        
        return VStack(spacing: 0) {
            // 主容器 HStack，包含可点击区域和操作按钮
            HStack(alignment: .center, spacing: 0) {
                
                // 可点击的渐变条部分
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedClientCodes.remove(clientGroup.id)
                        } else {
                            expandedClientCodes.insert(clientGroup.id)
                        }
                    }
                }) {
                    HStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("**\(displayClientName)**")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            // 移除基金支数显示
                            // Text("\(clientGroup.holdings.count)支")
                            //     .font(.system(size: 11, design: .monospaced))
                            //     .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 操作按钮（改名、删除）
                        HStack(spacing: 8) {
                            Button("改名") {
                                clientToRename = clientGroup
                                newClientName = clientGroup.clientName
                                isShowingRenameAlert = true
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                            .buttonStyle(PlainButtonStyle())
                            .opacity(isExpanded ? 1 : 0) // 展开时显示
                            
                            Button("删除") {
                                clientToDelete = clientGroup
                                isShowingDeleteAlert = true
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                            .buttonStyle(PlainButtonStyle())
                            .opacity(isExpanded ? 1 : 0) // 展开时显示
                        }
                        .animation(.easeInOut(duration: 0.2).delay(isExpanded ? 0.1 : 0), value: isExpanded) // 增加动画延迟
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [baseColor.opacity(0.8), Color.clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            // 外部 HACK：通过 padding 来实现展开时的右侧缩进效果
            .padding(.trailing, isExpanded ? 20 : 0)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
            
            // 展开的内容 (重新添加整体卡片样式)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) { // 使用 spacing 分隔行
                    // 使用 ForEach 来显示基金持仓列表
                    ForEach(clientGroup.holdings) { holding in
                        
                        HoldingRowForManagement(holding: holding) {
                            selectedHolding = holding
                        }
                        // 移除 .padding(.vertical) 和 Divider，改用 VStack spacing
                    }
                }
                .padding(16) // 整体卡片内边距
                .background(Color(.secondarySystemGroupedBackground)) // 卡片背景
                .cornerRadius(10) // 卡片圆角
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4) // 卡片阴影
                .padding(.top, 8)
                .padding(.leading, 20) // 保持左侧缩进
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95))
                            .animation(.easeInOut(duration: 0.25).delay(0.15)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                            .animation(.easeInOut(duration: 0.2))
                    )
                )
            }
        }
        // 移除多余的水平填充，依赖父级 ScrollView 的 padding(16)
        .padding(.vertical, 4)
    }

    private func renameClient() async {
        guard let oldClientName = clientToRename?.clientName, !newClientName.isEmpty else { return }
        
        if oldClientName == newClientName { return }
        
        dataManager.holdings = dataManager.holdings.map { holding in
            var updatedHolding = holding
            if holding.clientName == oldClientName {
                updatedHolding.clientName = newClientName
            }
            return updatedHolding
        }
        
        dataManager.saveData()
        await fundService.addLog("ManageHoldingsView: 客户 '\(oldClientName)' 已批量修改为 '\(newClientName)'。", type: .info)
        
        await MainActor.run {
            newClientName = ""
            clientToRename = nil
            refreshID = UUID()
        }
    }

    private func confirmDeleteClientHoldings() async {
        guard let client = clientToDelete else { return }
        
        let holdingsToDeleteCount = dataManager.holdings.filter { $0.clientName == client.clientName }.count
        dataManager.holdings.removeAll { $0.clientName == client.clientName }
        
        dataManager.saveData()
        await fundService.addLog("ManageHoldingsView: 已批量删除客户 '\(client.clientName)' 名下的 \(holdingsToDeleteCount) 个持仓。", type: .info)
        
        await MainActor.run {
            clientToDelete = nil
            isShowingDeleteAlert = false
            refreshID = UUID()
        }
    }
}

// MARK: - HoldingRowForManagement (维持简洁)
struct HoldingRowForManagement: View {
    let holding: FundHolding
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(holding.fundName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("[\(holding.fundCode)]")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("购买金额")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(holding.purchaseAmount, specifier: "%.2f")元")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("购买份额")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(holding.purchaseShares, specifier: "%.2f")份")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("购买日期")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(holding.purchaseDate, formatter: DateFormatter.shortDate)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                if !holding.remarks.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Text("备注:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(holding.remarks)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 确保占满宽度
        // 保持简洁，不添加卡片样式修饰符
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}
