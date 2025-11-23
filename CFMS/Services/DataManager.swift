//定义了一个名为 DataManager 的 ObservableObject 类，它是整个应用程序的核心数据管理层。
import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ProfitResult: Codable {
    var absolute: Double
    var annualized: Double
}

struct FavoriteItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var url: String
}

enum DataManagerError: Error {
    case invalidHoldingData
    case holdingNotFound
    case fileAccessError
    case fileEncodingError
    case csvParseError(String)
}

enum CSVImportError: Error {
    case fileNotFound
    case fileReadError(Error)
    case missingRequiredField(String, lineIndex: Int)
    case invalidNumberFormat(String, lineIndex: Int)
    case invalidDateFormat(String, lineIndex: Int)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "CSV文件不存在"
        case .fileReadError(let error):
            return "文件读取错误: \(error.localizedDescription)"
        case .missingRequiredField(let fieldName, let lineIndex):
            return "第 \(lineIndex + 1) 行缺少必需字段: \(fieldName)"
        case .invalidNumberFormat(let fieldValue, let lineIndex):
            return "第 \(lineIndex + 1) 行数值格式错误: \(fieldValue)"
        case .invalidDateFormat(let dateString, let lineIndex):
            return "第 \(lineIndex + 1) 行日期格式错误: \(dateString)"
        }
    }
}

// MARK: - CSV Export Document
struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var message: String
    
    init(message: String) {
        self.message = message
    }
    
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadCorruptFile)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: message.data(using: .utf8)!)
    }
}

class DataManager: ObservableObject {
    @Published var holdings: [FundHolding] = []
    @Published var favorites: [FavoriteItem] = []
    @Published var isPrivacyMode: Bool = false

    @Published var isRefreshing: Bool = false
    @Published var showRefreshButton: Bool = false
    @Published var disableDateTap: Bool = false
    @Published var refreshProgress: (current: Int, total: Int) = (0, 0)
    @Published var currentRefreshingClientName: String = ""
    @Published var currentRefreshingClientID: String = ""

    @Published var isImportingCSV: Bool = false
    @Published var importProgress: (current: Int, total: Int) = (0, 0)
    @Published var currentImportingFileName: String = ""
    
    // CSV 导入导出相关
    @Published var csvExportDocument: CSVExportDocument?
    @Published var isExportingCSV: Bool = false
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    private let holdingsKey = "fundHoldings"
    private let favoritesKey = "Favorites"
    private let privacyModeKey = "isPrivacyMode"
    
    private var refreshButtonTimer: Timer?
    private var refreshCooldownTimer: Timer?
    
    init() {
        loadData()
    }

    func loadData() {
        var decodedHoldings: [FundHolding] = []
        if let data = UserDefaults.standard.data(forKey: holdingsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                decodedHoldings = try decoder.decode([FundHolding].self, from: data)
                print("DataManager: 持仓数据加载成功。总持仓数: \(decodedHoldings.count)")
            } catch {
                print("DataManager: 持仓数据加载失败或解码错误: \(error.localizedDescription)")
            }
        } else {
            print("DataManager: 没有找到 UserDefaults 中的持仓数据。")
        }

        self.isPrivacyMode = UserDefaults.standard.bool(forKey: privacyModeKey)
        
        self.holdings = decodedHoldings
    }

    func saveData() {
        do {
            let holdingsEncoder = JSONEncoder()
            holdingsEncoder.dateEncodingStrategy = .iso8601
            let holdingsData = try holdingsEncoder.encode(self.holdings)
            UserDefaults.standard.set(holdingsData, forKey: holdingsKey)
            
            let favoritesEncoder = JSONEncoder()
            let favoritesData = try favoritesEncoder.encode(self.favorites)
            UserDefaults.standard.set(favoritesData, forKey: favoritesKey)
            UserDefaults.standard.set(self.isPrivacyMode, forKey: privacyModeKey)
            
            print("DataManager: 所有数据保存成功。")
        } catch {
            print("DataManager: 数据保存失败或编码错误: \(error.localizedDescription)")
        }
    }

    func addHolding(_ holding: FundHolding) throws {
        guard holding.isValidHolding else {
            throw DataManagerError.invalidHoldingData
        }
        
        var tempHoldings = self.holdings
        tempHoldings.append(holding)
        self.holdings = tempHoldings
        self.saveData()
        print("DataManager: 添加新持仓: \(holding.fundCode) - \(holding.clientName)")
    }
    
    func updateHolding(_ updatedHolding: FundHolding) throws {
        guard updatedHolding.isValidHolding else {
            throw DataManagerError.invalidHoldingData
        }
        
        if let index = holdings.firstIndex(where: { $0.id == updatedHolding.id }) {
            var tempHoldings = self.holdings
            tempHoldings[index] = updatedHolding
            self.holdings = tempHoldings
            self.saveData()
            print("DataManager: 更新持仓: \(updatedHolding.fundCode) - \(updatedHolding.clientName)")
        } else {
            throw DataManagerError.holdingNotFound
        }
    }
    
    func deleteHolding(at offsets: IndexSet) {
        var tempHoldings = self.holdings
        tempHoldings.remove(atOffsets: offsets)
        self.holdings = tempHoldings
        self.saveData()
        print("DataManager: 删除持仓。")
    }

    func togglePinStatus(forHoldingId id: UUID) {
        if let index = holdings.firstIndex(where: { $0.id == id }) {
            var tempHoldings = self.holdings
            tempHoldings[index].isPinned.toggle()
            if tempHoldings[index].isPinned {
                tempHoldings[index].pinnedTimestamp = Date()
            } else {
                tempHoldings[index].pinnedTimestamp = nil
            }
            self.holdings = tempHoldings
            self.saveData()
            print("DataManager: 持仓 \(tempHoldings[index].fundCode) 置顶状态切换为 \(tempHoldings[index].isPinned)。")
        }
    }

    func calculateProfit(for holding: FundHolding) -> ProfitResult {
        guard holding.purchaseShares > 0 && holding.currentNav >= 0 && holding.purchaseAmount > 0 else {
            return ProfitResult(absolute: 0.0, annualized: 0.0)
        }

        let currentMarketValue = holding.currentNav * holding.purchaseShares
        let absoluteProfit = currentMarketValue - holding.purchaseAmount

        let calendar = Calendar.current
        let holdingStartDate = calendar.startOfDay(for: holding.purchaseDate)
        let holdingEndDate = calendar.startOfDay(for: holding.navDate)

        guard let days = calendar.dateComponents([.day], from: holdingStartDate, to: holdingEndDate).day else {
            return ProfitResult(absolute: absoluteProfit, annualized: 0.0)
        }
        
        let holdingDays = Double(days) + 1.0
        
        guard holdingDays > 0 else {
            return ProfitResult(absolute: absoluteProfit, annualized: 0.0)
        }

        let annualizedReturn = (absoluteProfit / holding.purchaseAmount) / holdingDays * 365.0
        
        return ProfitResult(absolute: absoluteProfit, annualized: annualizedReturn * 100)
    }

    func togglePrivacyMode() {
        self.isPrivacyMode.toggle()
        self.saveData()
        print("DataManager: 隐私模式切换为 \(self.isPrivacyMode)。")
    }

    func obscuredName(for name: String) -> String {
        guard isPrivacyMode else {
            return name
        }
        
        if let firstCharacter = name.first {
            return String(firstCharacter) + (String(repeating: "*", count: name.count - 1))
        }
        return ""
    }
    
    func triggerRefreshButton() {
        guard !disableDateTap else { return }

        showRefreshButton = true
        refreshButtonTimer?.invalidate()
        refreshButtonTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            self.showRefreshButton = false
        }

        disableDateTap = true
        refreshCooldownTimer?.invalidate()
        refreshCooldownTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            self.disableDateTap = false
        }
    }
    
    func startRefresh() {
        isRefreshing = true
        refreshProgress = (0, holdings.count)
        currentRefreshingClientName = ""
        currentRefreshingClientID = ""
    }
    
    func completeRefresh() {
        isRefreshing = false
        currentRefreshingClientName = ""
        currentRefreshingClientID = ""
    }

    // MARK: - CSV 导入导出方法
    
    /// 导出持仓数据到CSV
    func exportHoldingsToCSV() -> CSVExportDocument? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var csvString = "客户姓名,基金代码,购买金额,购买份额,购买日期,客户号,备注\n"
        
        for holding in holdings {
            let formattedDate = dateFormatter.string(from: holding.purchaseDate)
            let amountStr = String(format: "%.2f", holding.purchaseAmount)
            let sharesStr = String(format: "%.2f", holding.purchaseShares)
            
            csvString += "\(holding.clientName),\(holding.fundCode),\(amountStr),\(sharesStr),\(formattedDate),\(holding.clientID),\(holding.remarks)\n"
        }
        
        return CSVExportDocument(message: csvString)
    }
    
    /// 生成导出文件名
    func generateExportFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return "fundlist_\(dateString).csv"
    }
    
    /// 处理文件导入
    func processImportedFile(url: URL) async {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        if !canAccess {
            await showToastMessage("无法访问文件，请检查权限设置")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let csvString = String(data: data, encoding: .utf8) else {
                await showToastMessage("文件编码错误，无法读取内容")
                return
            }
            
            await processCSVContent(csvString: csvString, fileName: url.lastPathComponent)
            
        } catch {
            await showToastMessage("文件读取失败: \(error.localizedDescription)")
        }
    }
    
    /// 处理CSV内容
    private func processCSVContent(csvString: String, fileName: String) async {
        let lines = csvString.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard lines.count > 1 else {
            await showToastMessage("导入失败：CSV文件为空或只有标题行")
            return
        }
        
        let headers = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let columnMapping: [String: [String]] = [
            "客户姓名": ["客户姓名", "姓名"],
            "基金代码": ["基金代码", "代码"],
            "购买金额": ["购买金额", "持仓成本（元）", "持仓成本", "成本"],
            "购买份额": ["购买份额", "当前份额", "份额"],
            "购买日期": ["购买日期", "最早购买日期", "日期"],
            "客户号": ["客户号", "核心客户号"],
            "备注": ["备注"]
        ]

        var columnIndices = [String: Int]()
        var missingRequiredHeaders: [String] = []

        for (key, aliases) in columnMapping {
            var found = false
            for alias in aliases {
                if let index = headers.firstIndex(where: { $0.contains(alias) }) {
                    columnIndices[key] = index
                    found = true
                    break
                }
            }
            if !found && ["基金代码", "购买金额", "购买份额", "客户号"].contains(key) {
                missingRequiredHeaders.append(key)
            }
        }

        if !missingRequiredHeaders.isEmpty {
            let missingColumnsString = missingRequiredHeaders.joined(separator: ", ")
            await showToastMessage("导入失败：缺少必要的列 (\(missingColumnsString))")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var existingHoldingsKeys: Set<String> = Set(holdings.map { $0.createDeduplicationKey() })

        var importedCount = 0
        var duplicateCount = 0
        
        await MainActor.run {
            isImportingCSV = true
            currentImportingFileName = fileName
            importProgress = (0, lines.count)
        }
        
        for i in 1..<lines.count {
            let values = lines[i].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard values.count >= headers.count else { continue }
            
            guard let fundCodeIndex = columnIndices["基金代码"],
                             let fundCode = values[safe: fundCodeIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            let cleanedFundCode = String(format: "%06d", Int(fundCode) ?? 0)
            
            guard let amountIndex = columnIndices["购买金额"],
                             let amountStr = values[safe: amountIndex]?.trimmingCharacters(in: .whitespacesAndNewlines),
                             let amount = Double(amountStr) else { continue }
            let cleanedAmount = (amount * 100).rounded() / 100

            guard let sharesIndex = columnIndices["购买份额"],
                             let sharesStr = values[safe: sharesIndex]?.trimmingCharacters(in: .whitespacesAndNewlines),
                             let shares = Double(sharesStr) else { continue }
            let cleanedShares = (shares * 100).rounded() / 100

            var purchaseDate = Date()
            if let dateIndex = columnIndices["购买日期"],
               let dateStr = values[safe: dateIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if let date = dateFormatter.date(from: dateStr) {
                    purchaseDate = date
                }
            }

            guard let clientIDIndex = columnIndices["客户号"],
                             let clientID = values[safe: clientIDIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            let desiredLength = 12
            let currentLength = clientID.count
            var cleanedClientID = clientID

            if currentLength < desiredLength {
                let numberOfZerosToAdd = desiredLength - currentLength
                let leadingZeros = String(repeating: "0", count: numberOfZerosToAdd)
                cleanedClientID = leadingZeros + clientID
            }

            var clientName: String
            if let clientNameIndex = columnIndices["客户姓名"],
               let nameFromCSV = values[safe: clientNameIndex]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !nameFromCSV.isEmpty {
                clientName = nameFromCSV
            } else {
                clientName = cleanedClientID
            }

            let remarks = columnIndices["备注"].flatMap { values[safe: $0]?.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            
            let newHolding = FundHolding(
                clientName: clientName,
                clientID: cleanedClientID,
                fundCode: cleanedFundCode,
                purchaseAmount: cleanedAmount,
                purchaseShares: cleanedShares,
                purchaseDate: purchaseDate,
                remarks: remarks
            )

            let deduplicationKey = newHolding.createDeduplicationKey()
            
            if !existingHoldingsKeys.contains(deduplicationKey) {
                do {
                    try addHolding(newHolding)
                    existingHoldingsKeys.insert(deduplicationKey)
                    importedCount += 1
                } catch {
                    print("导入失败: \(clientName)-\(cleanedFundCode) - \(error.localizedDescription)")
                }
            } else {
                duplicateCount += 1
            }
            
            // 更新进度
            await MainActor.run {
                importProgress = (i, lines.count)
            }
        }
        
        await MainActor.run {
            isImportingCSV = false
            importProgress = (0, 0)
            currentImportingFileName = ""
        }
        
        saveData()
        
        let message = "导入成功：\(importedCount) 条记录，跳过 \(duplicateCount) 条重复记录"
        await showToastMessage(message)
        
        NotificationCenter.default.post(name: NSNotification.Name("HoldingsDataUpdated"), object: nil)
    }
    
    /// 显示Toast消息
    @MainActor
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }
    
    // MARK: - 旧版导入方法（保持兼容性）
    func importFromCSV(fileURL: URL) {
        print("DataManager: 开始导入CSV文件: \(fileURL)")

        DispatchQueue.main.async {
            self.isImportingCSV = true
            self.currentImportingFileName = fileURL.lastPathComponent
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("DataManager: CSV文件不存在: \(fileURL.path)")
            completeCSVImport(importedCount: 0, errorCount: 1, error: CSVImportError.fileNotFound)
            return
        }
        
        do {
            let csvData = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = csvData.components(separatedBy: .newlines)
            
            print("DataManager: CSV文件行数: \(lines.count)")

            DispatchQueue.main.async {
                self.importProgress = (0, lines.count)
            }
            
            var importedCount = 0
            var errorCount = 0
            var importedHoldings: [FundHolding] = []

            for (index, line) in lines.enumerated() {
                DispatchQueue.main.async {
                    self.importProgress = (index, lines.count)
                }
                guard index > 0, !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                    print("DataManager: 跳过第 \(index) 行: \(line)")
                    continue
                }

                let columns = parseCSVLine(line)
                
                print("DataManager: 解析第 \(index) 行: \(columns)")

                if columns.count >= 6 {
                    do {
                        let holding = try createFundHoldingFromCSVColumns(columns, lineIndex: index)
                        importedHoldings.append(holding)
                        importedCount += 1
                        print("DataManager: 成功解析第 \(index) 行数据: \(holding.clientName) - \(holding.fundCode)")
                    } catch {
                        errorCount += 1
                        print("DataManager: 解析第 \(index) 行失败: \(error), 数据: \(line)")
                    }
                } else {
                    errorCount += 1
                    print("DataManager: 第 \(index) 行列数不足，期望至少6列，实际: \(columns.count), 数据: \(line)")
                }
            }

            for holding in importedHoldings {
                do {
                    try addHolding(holding)
                } catch {
                    errorCount += 1
                    print("DataManager: 添加持仓失败: \(error)")
                }
            }
            
            print("DataManager: CSV导入完成: 成功 \(importedCount) 条，失败 \(errorCount) 条")

            completeCSVImport(importedCount: importedCount, errorCount: errorCount, error: nil)

            cleanupTempFile(fileURL)
            
        } catch {
            print("DataManager: CSV文件读取失败: \(error)")

            completeCSVImport(importedCount: 0, errorCount: 1, error: CSVImportError.fileReadError(error))
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for character in line {
            switch character {
            case "\"":
                inQuotes.toggle()
            case ",":
                if inQuotes {
                    currentField.append(character)
                } else {
                    result.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                }
            default:
                currentField.append(character)
            }
        }

        result.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return result
    }
    
    private func createFundHoldingFromCSVColumns(_ columns: [String], lineIndex: Int) throws -> FundHolding {
        let clientName = columns[0].trimmingCharacters(in: .whitespaces)
        let clientID = columns[1].trimmingCharacters(in: .whitespaces)
        let fundCode = columns[2].trimmingCharacters(in: .whitespaces)

        guard !clientName.isEmpty else {
            throw CSVImportError.missingRequiredField("客户姓名", lineIndex: lineIndex)
        }
        
        guard !clientID.isEmpty else {
            throw CSVImportError.missingRequiredField("客户ID", lineIndex: lineIndex)
        }
        
        guard !fundCode.isEmpty else {
            throw CSVImportError.missingRequiredField("基金代码", lineIndex: lineIndex)
        }

        guard let purchaseAmount = Double(columns[3].trimmingCharacters(in: .whitespaces)) else {
            throw CSVImportError.invalidNumberFormat(columns[3], lineIndex: lineIndex)
        }
        
        guard let purchaseShares = Double(columns[4].trimmingCharacters(in: .whitespaces)) else {
            throw CSVImportError.invalidNumberFormat(columns[4], lineIndex: lineIndex)
        }

        let purchaseDate = try parseDate(columns[5].trimmingCharacters(in: .whitespaces), lineIndex: lineIndex)

        let remarks = columns.count > 6 ? columns[6].trimmingCharacters(in: .whitespaces) : ""

        return FundHolding(
            clientName: clientName,
            clientID: clientID,
            fundCode: fundCode,
            purchaseAmount: purchaseAmount,
            purchaseShares: purchaseShares,
            purchaseDate: purchaseDate,
            remarks: remarks,
            fundName: "",
            currentNav: 0.0,
            navDate: Date()
        )
    }
    
    private func parseDate(_ dateString: String, lineIndex: Int) throws -> Date {
        let formatters = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyy.MM.dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy年MM月dd日"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "zh_CN")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        throw CSVImportError.invalidDateFormat(dateString, lineIndex: lineIndex)
    }

    private func cleanupTempFile(_ fileURL: URL) {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            if fileURL.path.contains(tempDir.path) || fileURL.path.contains(documentsDir.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("DataManager: 已删除临时文件: \(fileURL)")
            }
        } catch {
            print("DataManager: 删除临时文件失败: \(error)")
        }
    }
    
    private func completeCSVImport(importedCount: Int, errorCount: Int, error: Error?) {
        DispatchQueue.main.async {
            self.isImportingCSV = false
            self.importProgress = (0, 0)
            self.currentImportingFileName = ""
        }

        var userInfo: [String: Any] = [
            "importedCount": importedCount,
            "errorCount": errorCount,
            "totalLines": importedCount + errorCount
        ]
        
        if let error = error {
            userInfo["error"] = error.localizedDescription
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CSVImportCompleted"),
            object: nil,
            userInfo: userInfo
        )
        
        print("DataManager: CSV导入完成通知已发送")
    }
    
    deinit {
        refreshButtonTimer?.invalidate()
        refreshCooldownTimer?.invalidate()
    }
}

// MARK: - 扩展 UTType 以支持 CSV 文件类型
extension UTType {
    static var commaSeparatedText: UTType {
        UTType(importedAs: "public.comma-separated-values-text")
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension FundHolding {
    func createDeduplicationKey() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let purchaseDateString = dateFormatter.string(from: purchaseDate)
        
        let amountString = String(format: "%.2f", purchaseAmount)
        let sharesString = String(format: "%.2f", purchaseShares)
        
        return "\(clientName)-\(fundCode)-\(amountString)-\(sharesString)-\(purchaseDateString)-\(clientID)-\(remarks)"
    }
}

// MARK: - 示例CSV格式说明
/*
 期望的CSV格式示例：
 
 客户姓名,客户ID,基金代码,购买金额,购买份额,购买日期,备注
 张三,A001,000001,50000.0,20000.0,2024-01-15,首次购买
 李四,B002,000002,30000.0,9375.0,2024-02-20,追加投资
 
 注意：
 1. 第一行是标题行，会被跳过
 2. 日期格式支持多种常见格式
 3. 如果字段包含逗号，需要用双引号包围
 4. 数值字段必须为有效的数字格式
 5. 必需字段：客户姓名、客户ID、基金代码、购买金额、购买份额、购买日期
 */
