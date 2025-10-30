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
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    requiredFieldsSection
                    
                    if showDatePicker {
                        datePickerSection
                    }

                    optionalFieldsSection
                    
                    actionButtons
                }
                .padding(.top)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
    
    private var requiredFieldsSection: some View {
        Group {
            clientNameInput
            fundCodeInput
            purchaseAmountInput
            purchaseSharesInput
            purchaseDateInput
        }
        .padding(.horizontal)
    }
    
    private var clientNameInput: some View {
        inputCard(title: "客户姓名", required: true) {
            TextField("请输入客户姓名", text: $clientName)
                .autocapitalization(.words)
        }
    }
    
    private var fundCodeInput: some View {
        inputCard(title: "基金代码", required: true) {
            TextField("请输入6位基金代码", text: $fundCode)
                .keyboardType(.numberPad)
                .onChange(of: fundCode) { oldValue, newValue in
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
        inputCard(title: "购买金额", required: true) {
            TextField("请输入购买金额", text: $purchaseAmount)
                .keyboardType(.decimalPad)
                .onChange(of: purchaseAmount) { oldValue, newValue in
                    purchaseAmount = newValue.filterNumericsAndDecimalPoint()
                }
        }
    }
    
    private var purchaseSharesInput: some View {
        inputCard(title: "购买份额", required: true) {
            TextField("请输入购买份额", text: $purchaseShares)
                .keyboardType(.decimalPad)
                .onChange(of: purchaseShares) { oldValue, newValue in
                    purchaseShares = newValue.filterNumericsAndDecimalPoint()
                }
        }
    }
    
    private var purchaseDateInput: some View {
        inputCard(title: "购买日期", required: true) {
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
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var datePickerSection: some View {
        VStack {
            DatePicker("", selection: $tempPurchaseDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
            
            HStack(spacing: 20) {
                Button("取消") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDatePicker = false
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.primary)
                .cornerRadius(8)
                
                Button("完成") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        purchaseDate = tempPurchaseDate
                        showDatePicker = false
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private var optionalFieldsSection: some View {
        VStack(alignment: .leading) {
            Text("选填信息")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            clientIDInput
            remarksInput
        }
        .padding(.horizontal)
    }
    
    private var clientIDInput: some View {
        inputCard(title: "客户号", required: false) {
            TextField("选填，最多12位数字", text: $clientID)
                .keyboardType(.numberPad)
                .onChange(of: clientID) { oldValue, newValue in
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
        inputCard(title: "备注", required: false) {
            TextField("选填，最多30个字符", text: $remarks)
                .onChange(of: remarks) { oldValue, newValue in
                    if newValue.count > 30 {
                        remarks = String(newValue.prefix(30))
                    }
                }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button("取消") {
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .foregroundColor(.primary)
            .cornerRadius(10)
            
            Button("保存修改") {
                saveChanges()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isFormValid ? Color.blue : Color.gray.opacity(0.1))
            .foregroundColor(isFormValid ? .white : .secondary)
            .cornerRadius(10)
            .disabled(!isFormValid)
        }
        .padding()
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
                    print("EditHoldingView: 基金 \(updatedHolding.fundCode) 信息已刷新并保存。")
                } else {
                    print("EditHoldingView: 警告 - 未找到持仓 \(updatedHolding.fundCode) 以刷新信息。")
                }
            }
        }
        
        dismiss()
    }

    private func inputCard<Content: View>(title: String, required: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                if required {
                    Text("*")
                        .foregroundColor(.red)
                }
                Spacer()
                content()
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
