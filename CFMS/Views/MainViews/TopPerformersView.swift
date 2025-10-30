import SwiftUI
import Foundation

struct TopPerformersView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    @State private var isFilterExpanded: Bool = false
    
    @State private var fundCodeFilterInput: String = ""
    @State private var minAmountInput: String = ""
    @State private var maxAmountInput: String = ""
    @State private var minDaysInput: String = ""
    @State private var maxDaysInput: String = ""
    @State private var varprofitInput: String = ""
    @State private var maxProfitInput: String = ""

    @State private var appliedFundCodeFilter: String = ""
    @State private var appliedMinAmount: String = ""
    @State private var appliedMaxAmount: String = ""
    @State private var appliedMinDays: String = ""
    @State private var appliedMaxDays: String = ""
    @State private var appliedMinProfit: String = ""
    @State private var appliedMaxProfit: String = ""
    
    @State private var showingToast = false
    @State private var toastMessage: String = ""
    @State private var isLoading = false
    @State private var precomputedHoldings: [(holding: FundHolding, profit: ProfitResult, daysHeld: Int)] = []
    
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled: Bool = false
    
    @State private var selectedSortKey: SortKey = .none
    @State private var sortOrder: SortOrder = .descending

    @State private var cachedSortedHoldings: [String: [(holding: FundHolding, profit: ProfitResult, daysHeld: Int)]] = [:]

    enum SortKey: String, CaseIterable, Identifiable {
        case none = "无排序"
        case amount = "金额"
        case profit = "收益"
        case yield = "收益率"
        case days = "天数"

        var id: String { self.rawValue }
        
        var next: SortKey {
            switch self {
            case .none: return .amount
            case .amount: return .profit
            case .profit: return .yield
            case .yield: return .days
            case .days: return .none
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .gray // 修改为灰色
            case .amount: return .blue
            case .profit: return .purple
            case .yield: return .orange
            case .days: return .red
            }
        }
    }
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case ascending = "升序"
        case descending = "降序"

        var id: String { self.rawValue }
    }
    
    private func sortButtonIconName() -> String {
        switch selectedSortKey {
        case .none: return "line.3.horizontal.decrease.circle"
        case .amount: return "dollarsign.circle"
        case .profit: return "chart.line.uptrend.xyaxis"
        case .yield: return "percent"
        case .days: return "calendar"
        }
    }
    
    private func refreshData() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            var computedData: [(holding: FundHolding, profit: ProfitResult, daysHeld: Int)] = []
            for holding in dataManager.holdings where holding.currentNav > 0 && holding.purchaseAmount > 0 {
                let profit = dataManager.calculateProfit(for: holding)
                let daysHeld = daysBetween(start: holding.purchaseDate, end: Date())
                computedData.append((holding: holding, profit: profit, daysHeld: daysHeld))
            }
            computedData.sort { $0.holding.fundCode < $1.holding.fundCode }
            DispatchQueue.main.async {
                self.precomputedHoldings = computedData
                self.isLoading = false
                self.cachedSortedHoldings.removeAll()
            }
        }
    }
    
    private func applyFilters() {
        appliedFundCodeFilter = fundCodeFilterInput
        appliedMinAmount = minAmountInput
        appliedMaxAmount = maxAmountInput
        appliedMinDays = minDaysInput
        appliedMaxDays = maxDaysInput
        appliedMinProfit = varprofitInput
        appliedMaxProfit = maxProfitInput
        hideKeyboard()
        
        let filteredCount = filteredAndSortedHoldings.count
        toastMessage = "已筛选出 \(filteredCount) 条记录"
        withAnimation { showingToast = true }
    }
    
    private func resetFilters() {
        fundCodeFilterInput = ""
        minAmountInput = ""
        maxAmountInput = ""
        minDaysInput = ""
        maxDaysInput = ""
        varprofitInput = ""
        maxProfitInput = ""
        
        appliedFundCodeFilter = ""
        appliedMinAmount = ""
        appliedMaxAmount = ""
        appliedMinDays = ""
        appliedMaxDays = ""
        appliedMinProfit = ""
        appliedMaxProfit = ""
        
        hideKeyboard()
        toastMessage = "筛选条件已重置"
        withAnimation { showingToast = true }
    }
    
    private var zeroProfitIndex: Int? {
        guard selectedSortKey == .yield || selectedSortKey == .profit else {
            return nil
        }
        
        let holdings = filteredAndSortedHoldings
        
        if sortOrder == .descending {
            if let lastPositiveIndex = holdings.lastIndex(where: { $0.profit.annualized >= 0 }) {
                return lastPositiveIndex < holdings.count - 1 ? lastPositiveIndex : nil
            }
            return nil
        } else {
            return holdings.lastIndex(where: { $0.profit.annualized < 0 })
        }
    }

    private var filteredAndSortedHoldings: [(holding: FundHolding, profit: ProfitResult, daysHeld: Int)] {
        let cacheKey = "\(appliedFundCodeFilter)_\(appliedMinAmount)_\(appliedMaxAmount)_\(appliedMinDays)_\(appliedMaxDays)_\(appliedMinProfit)_\(appliedMaxProfit)_\(selectedSortKey.rawValue)_\(sortOrder.rawValue)"
        
        if let cached = cachedSortedHoldings[cacheKey] {
            return cached
        }
        
        let minAmount = Double(appliedMinAmount).map { $0 * 10000 }
        let maxAmount = Double(appliedMaxAmount).map { $0 * 10000 }
        let minDays = Int(appliedMinDays)
        let maxDays = Int(appliedMaxDays)
        let minProfit = Double(appliedMinProfit)
        let maxProfit = Double(appliedMaxProfit)

        var results: [(holding: FundHolding, profit: ProfitResult, daysHeld: Int)] = []
        
        for item in precomputedHoldings {
            let holding = item.holding
            let profit = item.profit
            let daysHeld = item.daysHeld
            let annualizedProfit = profit.annualized
            let purchaseAmount = holding.purchaseAmount

            if !appliedFundCodeFilter.isEmpty && !holding.fundCode.localizedCaseInsensitiveContains(appliedFundCodeFilter) && !holding.fundName.localizedCaseInsensitiveContains(appliedFundCodeFilter) {
                continue
            }
            if let min = minAmount, purchaseAmount < min { continue }
            if let max = maxAmount, purchaseAmount > max { continue }
            if let min = minDays, daysHeld < min { continue }
            if let max = maxDays, daysHeld > max { continue }
            if let min = minProfit, annualizedProfit < min { continue }
            if let max = maxProfit, annualizedProfit > max { continue }
            results.append((holding: holding, profit: profit, daysHeld: daysHeld))
        }
        
        let sortedResults = sortHoldings(results)
        
        cachedSortedHoldings[cacheKey] = sortedResults
        
        if cachedSortedHoldings.count > 20 {
            let keysToRemove = Array(cachedSortedHoldings.keys.prefix(10))
            for key in keysToRemove {
                cachedSortedHoldings.removeValue(forKey: key)
            }
        }
        
        return sortedResults
    }
    
    private func sortHoldings(_ holdings: [(holding: FundHolding, profit: ProfitResult, daysHeld: Int)]) -> [(holding: FundHolding, profit: ProfitResult, daysHeld: Int)] {
        guard selectedSortKey != .none else {
            return holdings.sorted { $0.holding.fundCode < $1.holding.fundCode }
        }
        
        return holdings.sorted { (item1, item2) in
            let value1 = getSortValue(for: item1)
            let value2 = getSortValue(for: item2)
            
            if sortOrder == .ascending {
                return value1 < value2
            } else {
                return value1 > value2
            }
        }
    }
    
    private func getSortValue(for item: (holding: FundHolding, profit: ProfitResult, daysHeld: Int)) -> Double {
        switch selectedSortKey {
        case .amount:
            return item.holding.purchaseAmount
        case .profit:
            return item.profit.absolute
        case .yield:
            return item.profit.annualized
        case .days:
            return Double(item.daysHeld)
        case .none:
            return 0
        }
    }
    
    private func shouldShowDivider(at index: Int) -> Bool {
        guard let zeroIndex = zeroProfitIndex else { return false }
        return index == zeroIndex
    }
    
    private var headerContent: some View {
        HStack {
            HStack(spacing: 8) {
                filterButton
                sortButtons
            }
            
            Spacer()
            
            if isFilterExpanded {
                filterActionButtons
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .center) {
                backgroundView
                mainVStack
                loadingView
                toastView
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: isFilterExpanded)
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: handleOnDisappear)
        .onChange(of: selectedSortKey) { _, _ in
            cachedSortedHoldings.removeAll()
        }
        .onChange(of: sortOrder) { _, _ in
            cachedSortedHoldings.removeAll()
        }
        .onChange(of: dataManager.holdings) { _, _ in
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            cachedSortedHoldings.removeAll()
        }
    }
    
    private var mainContent: some View {
        ZStack(alignment: .center) {
            backgroundView
            mainVStack
            loadingView
            toastView
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var backgroundView: some View {
        Color(.systemGroupedBackground)
            .edgesIgnoringSafeArea(.all)
    }
    
    private var mainVStack: some View {
        VStack(spacing: 0) {
            headerContent
            filterSection
            contentSection
        }
    }
    
    private var topButtonBar: some View {
        HStack {
            HStack(spacing: 8) {
                filterButton
                sortButtons
            }
            
            Spacer()
            
            if isFilterExpanded {
                filterActionButtons
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private var filterButton: some View {
        GradientButton(
            icon: isFilterExpanded ? "rectangle.and.text.magnifyingglass" : "magnifyingglass",
            action: toggleFilter,
            colors: isFilterExpanded ? [Color(hex: "667eea"), Color(hex: "764ba2")] : [Color(hex: "f093fb"), Color(hex: "f5576c")]
        )
    }
    
    private var sortButtons: some View {
        SortButtonsView(
            selectedSortKey: $selectedSortKey,
            sortOrder: $sortOrder,
            sortButtonIconName: sortButtonIconName()
        )
    }
    
    private var filterActionButtons: some View {
        HStack(spacing: 10) {
            GradientButton(
                icon: "arrow.counterclockwise.circle",
                action: resetFilters,
                colors: [Color(hex: "fa709a"), Color(hex: "fee140")]
            )
            
            GradientButton(
                icon: "checkmark.circle",
                action: applyFilters,
                colors: [Color(hex: "43e97b"), Color(hex: "38f9d7")]
            )
        }
    }
    
    private var filterSection: some View {
        Group {
            if isFilterExpanded {
                FilterSectionView(
                    fundCodeFilterInput: $fundCodeFilterInput,
                    minAmountInput: $minAmountInput,
                    maxAmountInput: $maxAmountInput,
                    minDaysInput: $minDaysInput,
                    maxDaysInput: $maxDaysInput,
                    varprofitInput: $varprofitInput,
                    maxProfitInput: $maxProfitInput,
                    resetFilters: resetFilters,
                    applyFilters: applyFilters
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private var contentSection: some View {
        VStack(spacing: 0) {
            if precomputedHoldings.isEmpty {
                emptyStateView
            } else {
                holdingsTableView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 2)
        .padding(.top, 0)
    }
    
    private var emptyStateView: some View {
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
    }
    
    private var holdingsTableView: some View {
        VStack(spacing: 0) {
            headerRow
            holdingsList
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var headerRow: some View {
        GeometryReader { geometry in
            let widths = calculateWidths(from: geometry)
            HeaderRowView(
                numberWidth: widths.number,
                codeNameWidth: widths.codeName,
                amountWidth: widths.amount,
                profitWidth: widths.profit,
                daysWidth: widths.days,
                rateWidth: widths.rate,
                clientWidth: widths.client
            )
        }
        .frame(height: 32)
        .background(Color(.systemGray5))
    }
    
    private var holdingsList: some View {
        GeometryReader { geometry in
            let widths = calculateWidths(from: geometry)
            ScrollView {
                HoldingsListView(
                    filteredAndSortedHoldings: filteredAndSortedHoldings,
                    numberWidth: widths.number,
                    codeNameWidth: widths.codeName,
                    amountWidth: widths.amount,
                    profitWidth: widths.profit,
                    daysWidth: widths.days,
                    rateWidth: widths.rate,
                    clientWidth: widths.client,
                    isPrivacyModeEnabled: isPrivacyModeEnabled,
                    shouldShowDivider: shouldShowDivider
                )
            }
        }
    }
    
    private var loadingView: some View {
        Group {
            if isLoading {
                LoadingView()
            }
        }
    }
    
    private var toastView: some View {
        Group {
            if showingToast {
                ToastView(message: toastMessage, isShowing: $showingToast)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(1)
            }
        }
    }
    
    private func calculateWidths(from geometry: GeometryProxy) -> (number: CGFloat, codeName: CGFloat, amount: CGFloat, profit: CGFloat, days: CGFloat, rate: CGFloat, client: CGFloat) {
        let totalWidth = geometry.size.width - 4
        return (
            number: totalWidth * 0.07,
            codeName: totalWidth * 0.20,
            amount: totalWidth * 0.14,
            profit: totalWidth * 0.14,
            days: totalWidth * 0.10,
            rate: totalWidth * 0.16,
            client: totalWidth * 0.19
        )
    }
    
    private func toggleFilter() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isFilterExpanded.toggle()
        }
    }
    
    private func handleOnAppear() {
        if precomputedHoldings.isEmpty {
            refreshData()
        }
    }
    
    private func handleOnDisappear() {
        withAnimation {
            isFilterExpanded = false
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

struct FilterSectionView: View {
    @Binding var fundCodeFilterInput: String
    @Binding var minAmountInput: String
    @Binding var maxAmountInput: String
    @Binding var minDaysInput: String
    @Binding var maxDaysInput: String
    @Binding var varprofitInput: String
    @Binding var maxProfitInput: String
    
    let resetFilters: () -> Void
    let applyFilters: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                FilterFieldView(title: "代码/名称", placeholder: "输入代码或名称", text: $fundCodeFilterInput)
                FilterRangeFieldView(
                    title: "金额(万)",
                    minPlaceholder: "最低",
                    maxPlaceholder: "最高",
                    minText: $minAmountInput,
                    maxText: $maxAmountInput,
                    keyboardType: .decimalPad
                )
            }
            HStack(spacing: 12) {
                FilterRangeFieldView(
                    title: "持有天数",
                    minPlaceholder: "最低",
                    maxPlaceholder: "最高",
                    minText: $minDaysInput,
                    maxText: $maxDaysInput,
                    keyboardType: .numberPad
                )
                FilterRangeFieldView(
                    title: "收益率(%)",
                    minPlaceholder: "最低",
                    maxPlaceholder: "最高",
                    minText: $varprofitInput,
                    maxText: $maxProfitInput,
                    keyboardType: .numbersAndPunctuation
                )
            }
        }
        .padding(.vertical, 12)
        .transition(.opacity.combined(with: .scale))
    }
}

struct HeaderRowView: View {
    let numberWidth: CGFloat
    let codeNameWidth: CGFloat
    let amountWidth: CGFloat
    let profitWidth: CGFloat
    let daysWidth: CGFloat
    let rateWidth: CGFloat
    let clientWidth: CGFloat
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Group {
                Text("#")
                    .frame(width: numberWidth, alignment: .center)
                Divider().background(Color.secondary)
                Text("代码/名称")
                    .frame(width: codeNameWidth, alignment: .center)
                Divider().background(Color.secondary)
                Text("金额(万)")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: amountWidth, alignment: .center)
                Divider().background(Color.secondary)
                Text("收益(万)")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: profitWidth, alignment: .center)
                Divider().background(Color.secondary)
                Text("天数")
                    .frame(width: daysWidth, alignment: .center)
                Divider().background(Color.secondary)
                Text("收益率(%)")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: rateWidth, alignment: .center)
                Divider().background(Color.secondary)
                Text("客户")
                    .frame(width: clientWidth, alignment: .leading)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
        }
    }
}

struct HoldingsListView: View {
    let filteredAndSortedHoldings: [(holding: FundHolding, profit: ProfitResult, daysHeld: Int)]
    let numberWidth: CGFloat
    let codeNameWidth: CGFloat
    let amountWidth: CGFloat
    let profitWidth: CGFloat
    let daysWidth: CGFloat
    let rateWidth: CGFloat
    let clientWidth: CGFloat
    let isPrivacyModeEnabled: Bool
    let shouldShowDivider: (Int) -> Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(filteredAndSortedHoldings.enumerated()), id: \.element.holding.id) { index, item in
                    HoldingRowView(
                        index: index,
                        item: item,
                        numberWidth: numberWidth,
                        codeNameWidth: codeNameWidth,
                        amountWidth: amountWidth,
                        profitWidth: profitWidth,
                        daysWidth: daysWidth,
                        rateWidth: rateWidth,
                        clientWidth: clientWidth,
                        isPrivacyModeEnabled: isPrivacyModeEnabled,
                        showDivider: shouldShowDivider(index)
                    )
                    .id("\(item.holding.id)_\(index)")
                }
            }
        }
    }
}

struct SortButtonsView: View {
    @Binding var selectedSortKey: TopPerformersView.SortKey
    @Binding var sortOrder: TopPerformersView.SortOrder
    
    let sortButtonIconName: String
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation {
                    selectedSortKey = selectedSortKey.next
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: sortButtonIconName)
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
    }
}

struct FilterFieldView: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
        }
    }
}

struct FilterRangeFieldView: View {
    var title: String
    var minPlaceholder: String
    var maxPlaceholder: String
    @Binding var minText: String
    @Binding var maxText: String
    var keyboardType: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                TextField(minPlaceholder, text: $minText)
                    .keyboardType(keyboardType)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))
                Text("-")
                TextField(maxPlaceholder, text: $maxText)
                    .keyboardType(keyboardType)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))
            }
        }
    }
}

struct HoldingRowView: View {
    let index: Int
    let item: (holding: FundHolding, profit: ProfitResult, daysHeld: Int)
    let numberWidth: CGFloat
    let codeNameWidth: CGFloat
    let amountWidth: CGFloat
    let profitWidth: CGFloat
    let daysWidth: CGFloat
    let rateWidth: CGFloat
    let clientWidth: CGFloat
    let isPrivacyModeEnabled: Bool
    let showDivider: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Group {
                    Text("\(index + 1).")
                        .frame(width: numberWidth, alignment: .center)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    Divider().background(Color.secondary)
                    VStack(alignment: .center, spacing: 2) {
                        Text(item.holding.fundCode)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.tail)
                        Text(item.holding.fundName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.tail)
                    }
                    .frame(width: codeNameWidth, alignment: .center)
                    Divider().background(Color.secondary)
                    Text(formatAmountInTenThousands(item.holding.purchaseAmount))
                        .font(.system(size: 12))
                        .frame(width: amountWidth, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Divider().background(Color.secondary)
                    Text(formatAmountInTenThousands(item.profit.absolute))
                        .font(.system(size: 12))
                        .foregroundColor(Color.forValue(item.profit.absolute))
                        .frame(width: profitWidth, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Divider().background(Color.secondary)
                    Text(String(item.daysHeld))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: daysWidth, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Divider().background(Color.secondary)
                    Text(String(format: "%.2f", item.profit.annualized))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.forValue(item.profit.annualized))
                        .frame(width: rateWidth, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Divider().background(Color.secondary)
                    Text(isPrivacyModeEnabled ? processClientName(item.holding.clientName) : item.holding.clientName)
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                        .frame(width: clientWidth, alignment: .leading)
                }
            }
            .padding(.vertical, 6)
            
            if showDivider {
                Divider()
                    .background(Color.secondary)
                    .frame(height: 2)
            }
        }
    }
}

private func daysBetween(start: Date, end: Date) -> Int {
    let calendar = Calendar.current
    let startDate = calendar.startOfDay(for: start)
    let endDate = calendar.startOfDay(for: end)
    let components = calendar.dateComponents([.day], from: startDate, to: endDate)
    return components.day ?? 0
}

private func formatAmountInTenThousands(_ amount: Double) -> String {
    let tenThousand = amount / 10000.0
    return String(format: "%.2f", tenThousand)
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
