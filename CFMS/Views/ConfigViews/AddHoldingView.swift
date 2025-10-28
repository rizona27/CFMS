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
                ScrollView {
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
            .animation(.easeInOut(duration: 0.3), value: showDatePicker)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity
            ))
            .animation(.easeInOut(duration: 0.4), value: UUID())
        }

        // MARK: - View Components
        
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
            inputCard(title: "客户姓名", required: true, error: $clientNameError) {
                TextField("请输入客户姓名", text: $clientName)
                    .onChange(of: clientName) { oldValue, newValue in
                        validateClientName(newValue)
                    }
            }
        }
        
        private var fundCodeInput: some View {
            inputCard(title: "基金代码", required: true, error: $fundCodeError) {
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
            inputCard(title: "购买金额", required: true, error: $purchaseAmountError) {
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
            inputCard(title: "购买份额", required: true, error: $purchaseSharesError) {
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
            inputCard(title: "购买日期", required: true, error: .constant(nil)) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
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
                DatePicker("", selection: $purchaseDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                
                Button("完成") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDatePicker = false
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
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
            inputCard(title: "客户号", required: false, error: .constant(nil)) {
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
            inputCard(title: "备注", required: false, error: .constant(nil)) {
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
                
                Button("保存") {
                    Task {
                        await saveHolding()
                    }
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

        // MARK: - Helper Methods
        
        private func inputCard<Content: View>(title: String, required: Bool, error: Binding<String?>, @ViewBuilder content: () -> Content) -> some View {
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
                
                if let errorMessage = error.wrappedValue {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading)
                }
            }
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
    }

    private enum FieldType {
        case amount, shares
    }
