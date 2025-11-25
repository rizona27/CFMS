//编辑持仓模块
import SwiftUI

struct EditHoldingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService

    let originalHolding: FundHolding
    var onSave: (FundHolding) -> Void

    @State private var clientName: String
    @State private var clientID: String
    @State private var fundCode: String
    @State private var purchaseAmount: String
    @State private var purchaseShares: String
    @State private var purchaseDate: Date
    @State private var remarks: String

    @State private var showAlert = false
    @State private var alertMessage = ""

    @State private var showDatePicker = false
    @State private var tempPurchaseDate: Date

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    init(holding: FundHolding, onSave: @escaping (FundHolding) -> Void) {
        self.originalHolding = holding
        self.onSave = onSave
        
        _clientName = State(initialValue: holding.clientName)
        _clientID = State(initialValue: holding.clientID)
        _fundCode = State(initialValue: holding.fundCode)
        _purchaseAmount = State(initialValue: String(format: "%.2f", holding.purchaseAmount))
        _purchaseShares = State(initialValue: String(format: "%.2f", holding.purchaseShares))
        _purchaseDate = State(initialValue: holding.purchaseDate)
        _tempPurchaseDate = State(initialValue: holding.purchaseDate)
        _remarks = State(initialValue: holding.remarks)
    }

    private var isFormValid: Bool {
        return !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !fundCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !purchaseAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !purchaseShares.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               Double(purchaseAmount) != nil && Double(purchaseAmount)! > 0 &&
               Double(purchaseShares) != nil && Double(purchaseShares)! > 0
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerContent
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                requiredFieldsSection
                                
                                if showDatePicker {
                                    datePickerSection
                                        .id("datePicker")
                                }

                                optionalFieldsSection
                            }
                            .padding(.vertical, 16)
                        }
                        .onChange(of: showDatePicker) { newValue in
                            if newValue {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo("datePicker", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    
                    actionButtons
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                        .background(Color(.systemGroupedBackground))
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("输入错误", isPresented: $showAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .animation(.easeInOut(duration: 0.3), value: showDatePicker)
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private var headerContent: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton {
                    dismiss()
                }
                
                Spacer()
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
            
            Divider()
        }
    }

    private var requiredFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("必填信息")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            clientNameInput
            fundCodeInput
            purchaseAmountInput
            purchaseSharesInput
            purchaseDateInput
        }
    }
    
    private var clientNameInput: some View {
        inputCard(
            title: "客户姓名",
            required: true,
            systemImage: "person.fill",
            gradientColors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]
        ) {
            TextField("请输入客户姓名", text: $clientName)
                .autocapitalization(.words)
        }
    }
    
    private var fundCodeInput: some View {
        inputCard(
            title: "基金代码",
            required: true,
            systemImage: "number.circle.fill",
            gradientColors: [Color(hex: "667eea"), Color(hex: "764ba2")]
        ) {
            TextField("请输入6位基金代码", text: $fundCode)
                .keyboardType(.numberPad)
                .onChange(of: fundCode) { newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 6 {
                        fundCode = String(filtered.prefix(6))
                    } else {
                        fundCode = filtered
                    }
                }
        }
    }
    
    private var purchaseAmountInput: some View {
        inputCard(
            title: "购买金额",
            required: true,
            systemImage: "dollarsign.circle.fill",
            gradientColors: [Color(hex: "f093fb"), Color(hex: "f5576c")]
        ) {
            TextField("请输入购买金额", text: $purchaseAmount)
                .keyboardType(.decimalPad)
                .onChange(of: purchaseAmount) { newValue in
                    purchaseAmount = newValue.filterNumericsAndDecimalPoint()
                }
        }
    }
    
    private var purchaseSharesInput: some View {
        inputCard(
            title: "购买份额",
            required: true,
            systemImage: "chart.pie.fill",
            gradientColors: [Color(hex: "4ecdc4"), Color(hex: "44a08d")]
        ) {
            TextField("请输入购买份额", text: $purchaseShares)
                .keyboardType(.decimalPad)
                .onChange(of: purchaseShares) { newValue in
                    purchaseShares = newValue.filterNumericsAndDecimalPoint()
                }
        }
    }
    
    private var purchaseDateInput: some View {
        inputCard(
            title: "购买日期",
            required: true,
            systemImage: "calendar.circle.fill",
            gradientColors: [Color(hex: "fd746c"), Color(hex: "ff9068")]
        ) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    tempPurchaseDate = purchaseDate
                    showDatePicker.toggle()
                }
            }) {
                HStack {
                    Text(dateFormatter.string(from: purchaseDate))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down.circle.fill")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var datePickerSection: some View {
        VStack(spacing: 12) {
            DatePicker("", selection: $tempPurchaseDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("取消") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDatePicker = false
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("完成") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        purchaseDate = tempPurchaseDate
                        showDatePicker = false
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var optionalFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选填信息")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            clientIDInput
            remarksInput
        }
    }
    
    private var clientIDInput: some View {
        inputCard(
            title: "客户号",
            required: false,
            systemImage: "creditcard.fill",
            gradientColors: [Color(hex: "a8edea"), Color(hex: "fed6e3")]
        ) {
            TextField("选填，最多12位数字", text: $clientID)
                .keyboardType(.numberPad)
                .onChange(of: clientID) { newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 12 {
                        clientID = String(filtered.prefix(12))
                    } else {
                        clientID = filtered
                    }
                }
        }
    }
    
    private var remarksInput: some View {
        inputCard(
            title: "备注",
            required: false,
            systemImage: "text.bubble.fill",
            gradientColors: [Color(hex: "d4fc79"), Color(hex: "96e6a1")]
        ) {
            TextField("选填，最多30个字符", text: $remarks)
                .onChange(of: remarks) { newValue in
                    if newValue.count > 30 {
                        remarks = String(newValue.prefix(30))
                    }
                }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("取消") {
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("保存修改") {
                saveChanges()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isFormValid ? [Color(hex: "4facfe"), Color(hex: "00f2fe")] : [Color.gray, Color.gray.opacity(0.6)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(!isFormValid)
        }
        .padding(.top, 8)
    }

    private func inputCard<Content: View>(
        title: String,
        required: Bool,
        systemImage: String,
        gradientColors: [Color],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        if required {
                            Text("*")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    
                    content()
                        .font(.system(size: 16))
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
    }

    private func saveChanges() {
        if clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           fundCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           purchaseAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           purchaseShares.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertMessage = "所有必填字段（客户姓名、基金代码、购买金额、购买份额）都不能为空。"
            showAlert = true
            return
        }

        guard let amount = Double(purchaseAmount) else {
            alertMessage = "购买金额必须是有效的数字。"
            showAlert = true
            return
        }
        guard let shares = Double(purchaseShares) else {
            alertMessage = "购买份额必须是有效的数字。"
            showAlert = true
            return
        }
        
        if amount <= 0 || shares <= 0 {
            alertMessage = "购买金额和购买份额必须大于零。"
            showAlert = true
            return
        }

        var updatedHolding = originalHolding
        updatedHolding.clientName = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedHolding.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedHolding.fundCode = fundCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        updatedHolding.purchaseAmount = amount
        updatedHolding.purchaseShares = shares
        updatedHolding.purchaseDate = purchaseDate
        updatedHolding.remarks = remarks.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await fundService.addLog("EditHoldingView: 修改持仓信息 - 客户: \(updatedHolding.clientName), 基金: \(updatedHolding.fundCode), 金额: \(updatedHolding.purchaseAmount)", type: .info)
        }
        
        onSave(updatedHolding)
        print("EditHoldingView: 修改已保存。")
        
        if updatedHolding.fundCode != originalHolding.fundCode || !updatedHolding.isValid {
            Task { @MainActor in
                print("EditHoldingView: 基金代码发生变化或数据无效，重新获取基金信息 \(updatedHolding.fundCode)...")
                let fetchedInfo = await fundService.fetchFundInfo(code: updatedHolding.fundCode)
                
                if let index = dataManager.holdings.firstIndex(where: { $0.id == updatedHolding.id }) {
                    dataManager.holdings[index].fundName = fetchedInfo.fundName
                    dataManager.holdings[index].currentNav = fetchedInfo.currentNav
                    dataManager.holdings[index].navDate = fetchedInfo.navDate
                    dataManager.holdings[index].isValid = fetchedInfo.isValid
                    dataManager.saveData()
                    Task {
                        await fundService.addLog("EditHoldingView: 基金 \(updatedHolding.fundCode) 信息已刷新 - 净值: \(fetchedInfo.currentNav), 日期: \(fetchedInfo.navDate)", type: .success)
                    }
                } else {
                    Task {
                        await fundService.addLog("EditHoldingView: 警告 - 未找到持仓 \(updatedHolding.fundCode) 以刷新信息", type: .error)
                    }
                }
            }
        }
        
        dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
