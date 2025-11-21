// 一览页面主视图
import SwiftUI
import Foundation

enum SortKey: String, CaseIterable, Identifiable {
    case none = "无排序"
    case navReturn1m = "近1月"
    case navReturn3m = "近3月"
    case navReturn6m = "近6月"
    case navReturn1y = "近1年"

    var id: String { self.rawValue }
    var keyPathString: String? {
        switch self {
        case .navReturn1m: return "syl_1y"
        case .navReturn3m: return "syl_3y"
        case .navReturn6m: return "syl_6y"
        case .navReturn1y: return "syl_1n"
        case .none: return nil
        }
    }

    var next: SortKey {
        switch self {
        case .none: return .navReturn1m
        case .navReturn1m: return .navReturn3m
        case .navReturn3m: return .navReturn6m
        case .navReturn6m: return .navReturn1y
        case .navReturn1y: return .none
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .navReturn1m: return .blue
        case .navReturn3m: return .purple
        case .navReturn6m: return .orange
        case .navReturn1y: return .red
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case ascending = "升序"
    case descending = "降序"

    var id: String { self.rawValue }
}

struct SummaryView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled: Bool = false

    @State private var showingToast = false
    @State private var selectedSortKey: SortKey = .none
    @State private var sortOrder: SortOrder = .descending
    @State private var expandedFundCodes: Set<String> = []
    @State private var refreshID = UUID()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showingNavDateToast = false
    @State private var navDateToastMessage = ""
    @State private var hasShownInitialToast = false
    @State private var appLaunchTime: Date = Date()
    @State private var lastToastShowTime: Date = Date.distantPast
    @State private var toastTimer: Timer? = nil

    @State private var updatingTextState = 0
    @State private var updatingTextTimer: Timer?
    
    @State private var isRefreshing = false
    @State private var refreshProgress: (current: Int, total: Int) = (0, 0)

    @State private var showStatusText = true
    @State private var showRefreshButton = false
    @State private var autoHideTimer: Timer? = nil
    
    private let calendar = Calendar.current
    private let toastCooldown: TimeInterval = 3600
    private let toastDisplayTime: TimeInterval = 6.0
    
    private var previousWorkday: Date {
        let today = Date()
        var date = calendar.startOfDay(for: today)
        
        while true {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            let weekday = calendar.component(.weekday, from: date)
            if weekday >= 2 && weekday <= 6 {
                return date
            }
        }
    }
    
    private var benchmarkNavDate: Date? {
        let validHoldings = dataManager.holdings.filter { $0.isValid }
        guard !validHoldings.isEmpty else { return nil }
        
        return validHoldings
            .map { $0.navDate }
            .max()
    }
    
    private var hasAnyLatestNavDate: Bool {
        guard let benchmarkDate = benchmarkNavDate else { return false }
        
        let previousWorkdayStart = calendar.startOfDay(for: previousWorkday)
        let benchmarkDateStart = calendar.startOfDay(for: benchmarkDate)
        
        return calendar.isDate(benchmarkDateStart, inSameDayAs: previousWorkdayStart)
    }
    
    private var outdatedFunds: [FundHolding] {
        guard let benchmarkDate = benchmarkNavDate else { return [] }
        
        let benchmarkDateStart = calendar.startOfDay(for: benchmarkDate)
        return dataManager.holdings.filter { holding in
            guard holding.isValid else { return false }
            let holdingDateStart = calendar.startOfDay(for: holding.navDate)
            return !calendar.isDate(holdingDateStart, inSameDayAs: benchmarkDateStart)
        }
    }
    
    private var upToDateFunds: [FundHolding] {
        guard let benchmarkDate = benchmarkNavDate else { return [] }
        
        let benchmarkDateStart = calendar.startOfDay(for: benchmarkDate)
        return dataManager.holdings.filter { holding in
            holding.isValid && calendar.isDate(holding.navDate, inSameDayAs: benchmarkDateStart)
        }
    }
    
    private var outdatedFundCodes: [String] {
        Array(Set(outdatedFunds.map { $0.fundCode }))
    }
    
    private var latestNavDate: Date? {
        benchmarkNavDate
    }

    private var recognizedFunds: [String: [FundHolding]] {
        let recognizedFundCodes = Set(dataManager.holdings.filter { $0.isValid }.map { $0.fundCode })
        let filteredFunds = dataManager.holdings.filter { holding in
            recognizedFundCodes.contains(holding.fundCode)
        }
    
        var groupedFunds: [String: [FundHolding]] = [:]
        for holding in filteredFunds {
            if groupedFunds[holding.fundCode] == nil {
                groupedFunds[holding.fundCode] = []
            }
            groupedFunds[holding.fundCode]?.append(holding)
        }
        return groupedFunds
    }

    private var filteredHoldings: [FundHolding] {
        if searchText.isEmpty {
            return dataManager.holdings
        } else {
            return dataManager.holdings.filter { holding in
                holding.fundName.localizedCaseInsensitiveContains(searchText) ||
                holding.fundCode.localizedCaseInsensitiveContains(searchText) ||
                holding.clientName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var allGroupedFunds: [String: [FundHolding]] {
        var groupedFunds: [String: [FundHolding]] = [:]
        for holding in filteredHoldings {
            if groupedFunds[holding.fundCode] == nil {
                groupedFunds[holding.fundCode] = []
            }
            groupedFunds[holding.fundCode]?.append(holding)
        }
        return groupedFunds
    }

    private var sortedFundCodes: [String] {
        let codes = allGroupedFunds.keys.sorted()
    
        if selectedSortKey == .none {
            return codes.sorted()
        }
    
        let sortedCodes = codes.sorted { (code1, code2) in
            guard let funds1 = allGroupedFunds[code1]?.first,
                  let funds2 = allGroupedFunds[code2]?.first else {
                return false
            }
            
            let value1 = getSortValue(for: funds1, key: selectedSortKey)
            let value2 = getSortValue(for: funds2, key: selectedSortKey)

            if value1 != nil && value2 == nil {
                return true
            } else if value1 == nil && value2 != nil {
                return false
            } else if value1 == nil && value2 == nil {
                return code1 < code2
            }

            if sortOrder == .ascending {
                return value1! < value2!
            } else {
                return value1! > value2!
            }
        }
        return sortedCodes
    }

    private var areAnyCardsExpanded: Bool {
        !expandedFundCodes.isEmpty
    }

    private func toggleAllCards() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if areAnyCardsExpanded {
                expandedFundCodes.removeAll()
            } else {
                expandedFundCodes = Set(sortedFundCodes)
            }
        }
    }

    private func getSortValue(for fund: FundHolding, key: SortKey) -> Double? {
        switch key {
        case .navReturn1m: return fund.navReturn1m
        case .navReturn3m: return fund.navReturn3m
        case .navReturn6m: return fund.navReturn6m
        case .navReturn1y: return fund.navReturn1y
        case .none: return nil
        }
    }
    
    private func getHoldingReturn(for fund: FundHolding) -> Double? {
        guard fund.isValid && fund.purchaseAmount > 0 else { return nil }
        return (fund.totalValue - fund.purchaseAmount) / fund.purchaseAmount * 100
    }

    private func sortButtonIconName() -> String {
        switch selectedSortKey {
        case .none: return "line.3.horizontal.decrease.circle"
        case .navReturn1m: return "calendar"
        case .navReturn3m: return "calendar.day.timeline.leading"
        case .navReturn6m: return "calendar.day.timeline.trailing"
        case .navReturn1y: return "calendar.badge.clock"
        }
    }
    
    private func showToast() {
        toastTimer?.invalidate()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingToast = true
        }
        
        toastTimer = Timer.scheduledTimer(withTimeInterval: toastDisplayTime, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingToast = false
            }
        }
    }
    
    private func hideToast() {
        toastTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.3)) {
            showingToast = false
        }
    }

    private var updatingText: String {
        let baseText = "更新中"
        let dots = String(repeating: ".", count: updatingTextState % 4)
        return baseText + dots
    }

    private func startUpdatingTextAnimation() {
        updatingTextState = 0
        updatingTextTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updatingTextState = (updatingTextState + 1) % 4
        }
    }

    private func stopUpdatingTextAnimation() {
        updatingTextTimer?.invalidate()
        updatingTextTimer = nil
    }
    
    private func fundGroupItemView(fundCode: String, funds: [FundHolding]) -> some View {
        let baseColor = fundCode.morandiColor()
        let isExpanded = expandedFundCodes.contains(fundCode)
        let firstFund = funds.first!
        
        let shouldShowClientInfo = !isPrivacyModeEnabled || !searchText.isEmpty
        
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        if isExpanded {
                            expandedFundCodes.remove(fundCode)
                        } else {
                            expandedFundCodes.insert(fundCode)
                        }
                    }
                }) {
                    HStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("**\(firstFund.fundName)**")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(firstFund.fundCode)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !isPrivacyModeEnabled {
                            HStack(spacing: 2) {
                                Text("持有人数:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("\(funds.count)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .italic()
                                    .foregroundColor(colorForHoldingCount(funds.count))
                                Text("人")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Spacer().frame(width: 60)
                        }
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
                
                if selectedSortKey != .none {
                    VStack(alignment: .trailing) {
                        let valueString = getColumnValue(for: firstFund, keyPath: selectedSortKey.keyPathString)
                        let numberValue = Double(valueString.replacingOccurrences(of: "%", with: ""))
                        Text(valueString)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.forValue(numberValue))
                    }
                    .padding(.trailing, 16)
                    .padding(.leading, 8)
                }
            }
            .padding(.trailing, isExpanded ? 20 : 0)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: shouldShowClientInfo ? 12 : 8) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: shouldShowClientInfo ? 8 : 6) {
                            HStack(spacing: 16) {
                                Text("近1月:")
                                    .font(.system(size: shouldShowClientInfo ? 13 : 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 58, alignment: .leading)
                                Text(firstFund.navReturn1m?.formattedPercentage ?? "/")
                                    .font(.system(size: shouldShowClientInfo ? 13 : 15, weight: .medium))
                                    .foregroundColor(Color.forValue(firstFund.navReturn1m))
                                    .frame(minWidth: 60, alignment: .leading)
                            }
                            HStack(spacing: 16) {
                                Text("近6月:")
                                    .font(.system(size: shouldShowClientInfo ? 13 : 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 58, alignment: .leading)
                                Text(firstFund.navReturn6m?.formattedPercentage ?? "/")
                                    .font(.system(size: shouldShowClientInfo ? 13 : 15, weight: .medium))
                                    .foregroundColor(Color.forValue(firstFund.navReturn6m))
                                    .frame(minWidth: 60, alignment: .leading)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: shouldShowClientInfo ? 8 : 6) {
                            HStack(spacing: 16) {
                                Text("近3月:")
                                    .font(.system(size: shouldShowClientInfo ? 13 : 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 58, alignment: .leading)
                                Text(firstFund.navReturn3m?.formattedPercentage ?? "/")
                                    .font(.system(size: shouldShowClientInfo ? 13 : 15, weight: .medium))
                                    .foregroundColor(Color.forValue(firstFund.navReturn3m))
                                    .frame(minWidth: 60, alignment: .leading)
                            }
                            HStack(spacing: 16) {
                                Text("近1年:")
                                    .font(.system(size: shouldShowClientInfo ? 13 : 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 58, alignment: .leading)
                                Text(firstFund.navReturn1y?.formattedPercentage ?? "/")
                                    .font(.system(size: shouldShowClientInfo ? 13 : 15, weight: .medium))
                                    .foregroundColor(Color.forValue(firstFund.navReturn1y))
                                    .frame(minWidth: 60, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    if shouldShowClientInfo {
                        Divider()
                        
                        HStack(alignment: .top) {
                            Text("持有客户:")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: true, vertical: false)

                            combinedClientAndReturnText(funds: funds, getHoldingReturn: getHoldingReturn, sortOrder: sortOrder, isPrivacyModeEnabled: isPrivacyModeEnabled)
                                .font(.system(size: 13))
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                .padding(.top, 8)
                .padding(.leading, 20)
                .frame(maxWidth: .infinity)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.15)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8))
                        )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }
    
    private func colorForHoldingCount(_ count: Int) -> Color {
        if count == 1 {
            return .yellow
        } else if count <= 3 {
            return .orange
        } else {
            return .red
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
    
    @State private var isSearchExpanded: Bool = false
    
    private var progressToastView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("更新中")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Text(String(repeating: ".", count: updatingTextState % 4))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 20, alignment: .leading)
            }
            
            Text("[\(refreshProgress.current)/\(refreshProgress.total)]")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func onStatusTextTap() {
        guard !dataManager.holdings.isEmpty else { return }

        autoHideTimer?.invalidate()

        withAnimation(.easeInOut(duration: 1.0)) {
            showStatusText = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.0)) {
                self.showRefreshButton = true
                dataManager.showRefreshButton = true
            }

            autoHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                if !isRefreshing {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.showRefreshButton = false
                        dataManager.showRefreshButton = false
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            self.showStatusText = true
                        }
                    }
                }
            }
        }
    }
    
    private var headerContent: some View {
        VStack(spacing: 0) {
            HStack {
                GradientButton(
                    icon: areAnyCardsExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical",
                    action: toggleAllCards,
                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")]
                )

                GradientButton(
                    icon: isSearchExpanded ? "magnifyingglass.circle.fill" : "magnifyingglass.circle",
                    action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isSearchExpanded.toggle()
                        }
                    },
                    colors: [Color(hex: "f093fb"), Color(hex: "f5576c")]
                )
            
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation {
                            selectedSortKey = selectedSortKey.next
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: sortButtonIconName())
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(selectedSortKey == .none ? .primary : selectedSortKey.color)
                            if selectedSortKey != .none {
                                Text(selectedSortKey.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedSortKey.color)
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(selectedSortKey == .none ? Color.gray.opacity(0.1) : selectedSortKey.color.opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedSortKey == .none ? Color.gray.opacity(0.3) : selectedSortKey.color.opacity(0.3), lineWidth: 1)
                        )
                    }

                    if selectedSortKey != .none {
                        Button(action: {
                            withAnimation {
                                sortOrder = (sortOrder == .ascending) ? .descending : .ascending
                            }
                        }) {
                            Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(selectedSortKey.color)
                                .clipShape(Circle())
                                .shadow(color: selectedSortKey.color.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding(.leading, 8)
            
                Spacer()

                ZStack {
                    if showStatusText {
                        Button(action: {
                            onStatusTextTap()
                        }) {
                            if dataManager.holdings.isEmpty {
                                Text("暂无数据")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                            } else if hasAnyLatestNavDate {
                                Text(statusText)
                                    .font(.system(size: 14))
                                    .foregroundColor(statusColor)
                            } else {
                                Text(statusText)
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                            }
                        }
                        .disabled(dataManager.holdings.isEmpty)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    
                    if showRefreshButton {
                        Button(action: {
                            autoHideTimer?.invalidate()
                            Task {
                                await refreshAllFundInfo()
                            }
                        }) {
                            if isRefreshing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                    .frame(width: 32, height: 32)
                                    .background(AppTheme.primaryGradient)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(AppTheme.accentGradient)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: .themePrimary.opacity(0.3), radius: 3, x: 0, y: 2)
                            }
                        }
                        .disabled(isRefreshing)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .animation(.easeInOut(duration: 1.0), value: showStatusText)
                .animation(.easeInOut(duration: 1.0), value: showRefreshButton)
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
                            icon: "chart.bar.doc.horizontal",
                            title: "当前没有数据",
                            description: "请导入数据开始使用",
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
                    } else if filteredHoldings.isEmpty && !searchText.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "未找到符合条件的内容",
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
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(sortedFundCodes, id: \.self) { fundCode in
                                    if let funds = allGroupedFunds[fundCode] {
                                        fundGroupItemView(fundCode: fundCode, funds: funds)
                                            .id("\(fundCode)_\(funds.hashValue)")
                                    }
                                }
                            }
                            .padding(.bottom, 20)
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
                
                if isRefreshing {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .allowsHitTesting(true)
                        .zIndex(999)

                    VStack {
                        Spacer()
                        
                        progressToastView
                        
                        Spacer()
                    }
                    .zIndex(1000)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            
                if showingToast || showingNavDateToast {
                    VStack {
                        if showingToast {
                            CustomToastView(
                                outdatedCount: outdatedFundCodes.count,
                                sortedUniqueFunds: getSortedUniqueOutdatedFunds(),
                                isShowing: $showingToast,
                                showTime: toastDisplayTime
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            .onTapGesture {
                                hideToast()
                            }
                        }
                        
                        if showingNavDateToast {
                            ToastView(message: navDateToastMessage, isShowing: $showingNavDateToast)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(999)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isSearchExpanded)
        .id(refreshID)
        .onAppear {
            hasShownInitialToast = false
            appLaunchTime = Date()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkAndShowOutdatedToastIfNeeded()
            }
        }
        .onDisappear {
            toastTimer?.invalidate()
            autoHideTimer?.invalidate()
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearchExpanded = false
            }
            stopUpdatingTextAnimation()

            withAnimation(.none) {
                dataManager.showRefreshButton = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HoldingsDataUpdated"))) { _ in
            refreshID = UUID()
            hasShownInitialToast = false
            lastToastShowTime = Date.distantPast
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkAndShowOutdatedToastIfNeeded()
            }
        }
        .onChange(of: isPrivacyModeEnabled) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
        }
    }
    
    private var statusText: String {
        guard let latestDate = latestNavDate else {
            return "暂无数据"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        let dateString = formatter.string(from: latestDate)
        
        if hasAnyLatestNavDate {
            return "最新日期: \(dateString)"
        } else {
            let previousWorkdayString = formatter.string(from: previousWorkday)
            return "待更新: \(previousWorkdayString)"
        }
    }
    
    private var statusColor: Color {
        if hasAnyLatestNavDate {
            return Color(red: 0.4, green: 0.8, blue: 0.4)
        } else {
            return .orange
        }
    }
    
    private func checkAndShowOutdatedToastIfNeeded() {
        guard !dataManager.holdings.isEmpty && !outdatedFunds.isEmpty else {
            return
        }

        let currentTime = Date()
        
        if currentTime.timeIntervalSince(lastToastShowTime) < toastCooldown {
            return
        }

        if hasShownInitialToast {
            return
        }
        
        showToast()
        hasShownInitialToast = true
        lastToastShowTime = currentTime
    }
    
    private func getSortedUniqueOutdatedFunds() -> [(String, String)] {
        var uniqueFunds: [String: String] = [:]
        for fund in outdatedFunds {
            uniqueFunds[fund.fundCode] = fund.fundName
        }
        
        return uniqueFunds.sorted { $0.key < $1.key }
    }
    
    private func getColumnValue(for fund: FundHolding, keyPath: String?) -> String {
        guard let keyPath = keyPath else { return "/" }
        switch keyPath {
        case "syl_1y": return fund.navReturn1m?.formattedPercentage ?? "/"
        case "syl_3y": return fund.navReturn3m?.formattedPercentage ?? "/"
        case "syl_6y": return fund.navReturn6m?.formattedPercentage ?? "/"
        case "syl_1n": return fund.navReturn1y?.formattedPercentage ?? "/"
        default: return ""
        }
    }
    
    private func refreshAllFundInfo() async {
        await MainActor.run {
            isRefreshing = true
            refreshProgress = (0, dataManager.holdings.count)
            startUpdatingTextAnimation()
            NotificationCenter.default.post(name: Notification.Name("RefreshStarted"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("RefreshLockEnabled"), object: nil)
        }
        
        Task {
            await fundService.addLog("SummaryView: 开始刷新所有基金信息...", type: .info)
        }

        let totalCount = dataManager.holdings.count
        
        if totalCount == 0 {
            await MainActor.run {
                completeRefresh()
            }
            return
        }
        
        var updatedHoldings: [UUID: FundHolding] = [:]
        
        await withTaskGroup(of: (UUID, FundHolding?).self) { group in
            var iterator = dataManager.holdings.makeIterator()
            var activeTasks = 0
            
            while activeTasks < 3, let holding = iterator.next() {
                group.addTask {
                    await self.fetchHoldingWithRetry(holding: holding)
                }
                activeTasks += 1
            }

            while let result = await group.next() {
                activeTasks -= 1
                await self.processHoldingResult(result: result, updatedHoldings: &updatedHoldings, totalCount: totalCount)
                
                if let nextHolding = iterator.next() {
                    group.addTask {
                        await self.fetchHoldingWithRetry(holding: nextHolding)
                    }
                    activeTasks += 1
                }
            }
        }

        await MainActor.run {
            for (index, holding) in dataManager.holdings.enumerated() {
                if let updatedHolding = updatedHoldings[holding.id] {
                    dataManager.holdings[index] = updatedHolding
                }
            }
            
            dataManager.saveData()
            completeRefresh()
            
            let stats = (success: refreshProgress.current, fail: totalCount - refreshProgress.current)
            NotificationCenter.default.post(name: Notification.Name("RefreshCompleted"), object: nil, userInfo: ["stats": stats])

            NotificationCenter.default.post(name: Notification.Name("HoldingsDataUpdated"), object: nil)
            Task {
                await fundService.addLog("SummaryView: 所有基金信息刷新完成。", type: .info)
            }
        }
    }
    
    private func completeRefresh() {
        isRefreshing = false
        stopUpdatingTextAnimation()
        NotificationCenter.default.post(name: Notification.Name("RefreshLockDisabled"), object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.0)) {
                self.showRefreshButton = false
                dataManager.showRefreshButton = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.showStatusText = true
                }
            }
        }
    }
    
    private func fetchHoldingWithRetry(holding: FundHolding) async -> (UUID, FundHolding?) {
        var retryCount = 0
        
        while retryCount < 3 {
            let fetchedInfo = await fundService.fetchFundInfo(code: holding.fundCode)
            var updatedHolding = holding
            updatedHolding.fundName = fetchedInfo.fundName
            updatedHolding.currentNav = fetchedInfo.currentNav
            updatedHolding.navDate = fetchedInfo.navDate
            updatedHolding.isValid = fetchedInfo.isValid
            
            if fetchedInfo.isValid {
                let fundDetails = await fundService.fetchFundDetailsFromEastmoney(code: holding.fundCode)
                updatedHolding.navReturn1m = fundDetails.returns.navReturn1m
                updatedHolding.navReturn3m = fundDetails.returns.navReturn3m
                updatedHolding.navReturn6m = fundDetails.returns.navReturn6m
                updatedHolding.navReturn1y = fundDetails.returns.navReturn1y
                
                return (holding.id, updatedHolding)
            }
            
            retryCount += 1
            if retryCount < 3 {
                let retryDelay = Double(retryCount) * 0.5
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
        
        return (holding.id, nil)
    }
    
    private func processHoldingResult(result: (UUID, FundHolding?), updatedHoldings: inout [UUID: FundHolding], totalCount: Int) async {
        let (holdingId, updatedHolding) = result
        
        await MainActor.run {
            if let updatedHolding = updatedHolding {
                updatedHoldings[holdingId] = updatedHolding
                
                refreshProgress.current = min(refreshProgress.current + 1, totalCount)
                Task {
                    await fundService.addLog("基金 \(updatedHolding.fundCode) 刷新成功", type: .success)
                }
            } else {
                refreshProgress.current = min(refreshProgress.current + 1, totalCount)
                if let originalHolding = dataManager.holdings.first(where: { $0.id == holdingId }) {
                    Task {
                        await fundService.addLog("基金 \(originalHolding.fundCode) 刷新失败", type: .error)
                    }
                }
            }
        }
    }
}

struct CustomToastView: View {
    let outdatedCount: Int
    let sortedUniqueFunds: [(String, String)]
    @Binding var isShowing: Bool
    let showTime: Double
    
    private var toastHeight: CGFloat {
        let baseHeight: CGFloat = 60
        let lineHeight: CGFloat = 22
        let maxDisplayCount = min(5, sortedUniqueFunds.count)
        let contentHeight = CGFloat(maxDisplayCount) * lineHeight
        let maxHeight: CGFloat = 200
        
        return min(baseHeight + contentHeight, maxHeight)
    }
    
    private var optimalWidth: CGFloat {
        let maxNameLength = sortedUniqueFunds.prefix(5).map { fundCode, fundName in
            let displayName = fundName.count > 8 ? String(fundName.prefix(8)) + "..." : fundName
            return displayName.count + fundCode.count + 4
        }.max() ?? 0
        
        let baseWidth: CGFloat = 100
        let extraWidth = CGFloat(maxNameLength) * 7
        
        return min(baseWidth + extraWidth, 200)
    }
    
    private func colorForCount(_ count: Int) -> Color {
        if count == 1 {
            return .yellow
        } else if count <= 3 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("非最新日期净值: ")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(.darkGray))
                
                Text("\(outdatedCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .italic()
                    .foregroundColor(colorForCount(outdatedCount))
                
                Text(" 支")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(.darkGray))
            }
            
            if !sortedUniqueFunds.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(sortedUniqueFunds.prefix(5)), id: \.0) { fundCode, fundName in
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                let displayName = fundName.count > 8 ? String(fundName.prefix(8)) + "..." : fundName
                                Text(displayName)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text("[\(fundCode)]")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if sortedUniqueFunds.count > 5 {
                            Text("... 还有\(sortedUniqueFunds.count - 5)支")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: optimalWidth, height: toastHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private func combinedClientAndReturnText(funds: [FundHolding], getHoldingReturn: (FundHolding) -> Double?, sortOrder: SortOrder, isPrivacyModeEnabled: Bool) -> Text {
    let sortedFunds: [FundHolding]
    if sortOrder == .ascending {
        sortedFunds = funds.sorted {
            let return1 = getHoldingReturn($0) ?? -Double.infinity
            let return2 = getHoldingReturn($1) ?? -Double.infinity
            return return1 < return2
        }
    } else {
        sortedFunds = funds.sorted {
            let return1 = getHoldingReturn($0) ?? -Double.infinity
            let return2 = getHoldingReturn($1) ?? -Double.infinity
            return return1 > return2
        }
    }
    
    var combinedText: Text = Text("")
    
    guard !sortedFunds.isEmpty else {
        return Text("")
    }

    for (index, holding) in sortedFunds.enumerated() {
        let clientName = isPrivacyModeEnabled ? processClientName(holding.clientName) : holding.clientName
        var clientText = Text(clientName)
        
        if let holdingReturn = getHoldingReturn(holding) {
            clientText = clientText + Text("(\(holdingReturn.formattedPercentage))")
                .foregroundColor(Color.forValue(holdingReturn))
        } else {
            clientText = clientText + Text("(/)")
                .foregroundColor(.gray)
        }
    
        if index > 0 {
            combinedText = combinedText + Text("、")
        }
    
        combinedText = combinedText + clientText
    }
    
    return combinedText
}
