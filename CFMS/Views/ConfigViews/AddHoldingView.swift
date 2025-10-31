import SwiftUI

struct AddHoldingView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var fundService: FundService
    @Environment(\.dismiss) var dismiss

    @State private var clientName: String = ""
    @State private var clientID: String = ""
    @State private var fundCode: String = ""
    @State private var purchaseAmount: String = ""
    @State private var purchaseShares: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var remarks: String = ""

    @State private var clientNameError: String? = nil
    @State private var fundCodeError: String? = nil
    @State private var purchaseAmountError: String? = nil
    @State private var purchaseSharesError: String? = nil

    @State private var showDatePicker = false
    @State private var tempPurchaseDate: Date = Date()

    @Namespace private var datePickerNamespace

    private var isFormValid: Bool {
        return clientNameError == nil &&
               fundCodeError == nil &&
               purchaseAmountError == nil &&
               purchaseSharesError == nil &&
               !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !fundCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !purchaseAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !purchaseShares.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

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
                        .onChange(of: showDatePicker) { oldValue, newValue in
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
        .animation(.easeInOut(duration: 0.3), value: showDatePicker)
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private var headerContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        
                        Image(systemName: "chevron.backward.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                    .frame(width: 32, height: 32)
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
            error: $clientNameError,
            systemImage: "person.fill",
            gradientColors: [Color(hex: "4facfe"), Color(hex: "00f2fe")]
        ) {
            TextField("请输入客户姓名", text: $clientName)
                .onChange(of: clientName) { oldValue, newValue in
                    validateClientName(newValue)
                }
        }
    }
    
    private var fundCodeInput: some View {
        inputCard(
            title: "基金代码",
            required: true,
            error: $fundCodeError,
            systemImage: "number.circle.fill",
            gradientColors: [Color(hex: "667eea"), Color(hex: "764ba2")]
        ) {
            TextField("请输入6位基金代码", text: $fundCode)
                .keyboardType(.numberPad)
                .onChange(of: fundCode) { oldValue, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 6 {
                        fundCode = String(filtered.prefix(6))
                    } else {
                        fundCode = filtered
                    }
                    validateFundCode(fundCode)
                }
        }
    }
    
    private var purchaseAmountInput: some View {
        inputCard(
            title: "购买金额",
            required: true,
            error: $purchaseAmountError,
            systemImage: "dollarsign.circle.fill",
            gradientColors: [Color(hex: "f093fb"), Color(hex: "f5576c")]
        ) {
            TextField("请输入购买金额", text: $purchaseAmount)
                .keyboardType(.decimalPad)
                .onChange(of: purchaseAmount) { oldValue, newValue in
                    let filtered = newValue.filterNumericsAndDecimalPoint()
                    purchaseAmount = formatDecimalInput(filtered, maxDigits: 9)
                    validateAmount(purchaseAmount, field: .amount)
                }
        }
    }
    
    private var purchaseSharesInput: some View {
        inputCard(
            title: "购买份额",
            required: true,
            error: $purchaseSharesError,
            systemImage: "chart.pie.fill",
            gradientColors: [Color(hex: "4ecdc4"), Color(hex: "44a08d")]
        ) {
            TextField("请输入购买份额", text: $purchaseShares)
                .keyboardType(.decimalPad)
                .onChange(of: purchaseShares) { oldValue, newValue in
                    let filtered = newValue.filterNumericsAndDecimalPoint()
                    purchaseShares = formatDecimalInput(filtered, maxDigits: 9)
                    validateAmount(purchaseShares, field: .shares)
                }
        }
    }
    
    private var purchaseDateInput: some View {
        inputCard(
            title: "购买日期",
            required: true,
            error: .constant(nil),
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
            error: .constant(nil),
            systemImage: "creditcard.fill",
            gradientColors: [Color(hex: "a8edea"), Color(hex: "fed6e3")]
        ) {
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
        inputCard(
            title: "备注",
            required: false,
            error: .constant(nil),
            systemImage: "text.bubble.fill",
            gradientColors: [Color(hex: "d4fc79"), Color(hex: "96e6a1")]
        ) {
            TextField("选填，最多30个字符", text: $remarks)
                .onChange(of: remarks) { oldValue, newValue in
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
            
            Button("保存") {
                Task {
                    await saveHolding()
                }
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
        error: Binding<String?>,
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
            
            if let errorMessage = error.wrappedValue {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                .padding(.leading, 16)
            }
        }
        .padding(.horizontal)
    }

    private func validateClientName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            clientNameError = "姓名不能为空。"
            return
        }
        
        let filteredName = trimmedName.filterAllowedNameCharacters()
        
        if filteredName != trimmedName {
            clientNameError = "姓名只能包含汉字、英文字母和单个空格。"
            return
        }

        let containsChinese = trimmedName.range(of: "\\p{Han}", options: .regularExpression) != nil
        
        if containsChinese {
            if trimmedName.count > 5 {
                clientNameError = "姓名包含汉字时，总长度不能超过5个字符。"
            } else {
                clientNameError = nil
            }
        } else {
            if trimmedName.count > 15 {
                clientNameError = "英文姓名不超过15个字母。"
            } else {
                clientNameError = nil
            }
        }
    }
    
    private func validateFundCode(_ code: String) {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.isEmpty {
            fundCodeError = "基金代码不能为空。"
        } else if trimmedCode.count != 6 || !trimmedCode.allSatisfy({ $0.isNumber }) {
            fundCodeError = "基金代码必须是6位数字。"
        } else {
            fundCodeError = nil
        }
    }
    
    private func validateAmount(_ amount: String, field: FieldType) {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAmount.isEmpty {
            if field == .amount { purchaseAmountError = "购买金额不能为空。" }
            if field == .shares { purchaseSharesError = "购买份额不能为空。" }
            return
        }
        
        guard let value = Double(trimmedAmount), value > 0 else {
            if field == .amount { purchaseAmountError = "请输入非0正数。" }
            if field == .shares { purchaseSharesError = "请输入非0正数。" }
            return
        }
        
        if field == .amount { purchaseAmountError = nil }
        if field == .shares { purchaseSharesError = nil }
    }
    
    private func formatDecimalInput(_ input: String, maxDigits: Int) -> String {
        let components = input.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        var result = ""

        let integerPart = components.first ?? ""
        if integerPart.count > maxDigits {
            result = String(integerPart.prefix(maxDigits))
        } else {
            result = String(integerPart)
        }

        if components.count > 1 {
            let decimalPart = components[1]
            result += "." + String(decimalPart.prefix(2))
        }
        
        return result
    }

    private func saveHolding() async {
        guard isFormValid else {
            return
        }
        
        let amount = Double(purchaseAmount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
        let shares = Double(purchaseShares.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
        let trimmedClientName = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRemarks = remarks.trimmingCharacters(in: .whitespacesAndNewlines)

        let newHolding = FundHolding(
            clientName: trimmedClientName,
            clientID: trimmedClientID,
            fundCode: fundCode.uppercased(),
            purchaseAmount: amount,
            purchaseShares: shares,
            purchaseDate: purchaseDate,
            remarks: trimmedRemarks
        )

        do {
            try dataManager.addHolding(newHolding)
            await fundService.addLog("新增持仓: \(newHolding.fundCode) for \(newHolding.clientName)。", type: .info)

            await MainActor.run {
                Task { @MainActor in
                    if let index = dataManager.holdings.firstIndex(where: { $0.id == newHolding.id }) {
                        var holdingToUpdate = dataManager.holdings[index]
                        let fetchedInfo = await fundService.fetchFundInfo(code: holdingToUpdate.fundCode)
                        
                        holdingToUpdate.fundName = fetchedInfo.fundName
                        holdingToUpdate.currentNav = fetchedInfo.currentNav
                        holdingToUpdate.navDate = fetchedInfo.navDate
                        holdingToUpdate.isValid = fetchedInfo.isValid
                        
                        do {
                            try dataManager.updateHolding(holdingToUpdate)
                            await fundService.addLog("基金 \(holdingToUpdate.fundCode) 信息已刷新。", type: .info)
                        } catch {
                            await fundService.addLog("更新持仓失败: \(error.localizedDescription)", type: .error)
                        }
                    } else {
                        await fundService.addLog("警告: 未找到刚刚添加的持仓以刷新信息。", type: .error)
                    }
                }
                dismiss()
            }
        } catch {
            await fundService.addLog("添加持仓失败: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private enum FieldType {
    case amount, shares
}
