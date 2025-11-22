// CloudSyncManager.swift
import Foundation
import Combine
import SwiftUI

class CloudSyncManager: ObservableObject {
    @Published var isUploading: Bool = false
    @Published var isDownloading: Bool = false
    @Published var syncMessage: String = ""
    @Published var showSyncAlert: Bool = false
    @Published var syncAlertMessage: String = ""

    @Published var hasDownloadPermission: Bool = false

    var isNetworkAvailable: Bool {
        return true
    }
    
    private let baseURL = "https://cfms.crnas.uk:8315"
    private var cancellables = Set<AnyCancellable>()

    func checkDownloadPermissions(authService: AuthService) {
        if authService.isLoggedIn {
            hasDownloadPermission = true
        } else {
            hasDownloadPermission = false
        }
    }

    func uploadHoldingsToCloud(authService: AuthService, dataManager: DataManager) {
        guard let token = authService.authToken, let username = authService.currentUser?.username else {
            setAlertMessage("请先登录")
            return
        }
        
        isUploading = true
        syncMessage = "正在上传持仓数据..."
        
        let holdings = dataManager.holdings
        let requestData: [String: Any] = [
            "holdings": holdings.map { holding in
                var holdingDict: [String: Any] = [
                    "id": holding.id.uuidString,
                    "clientName": holding.clientName,
                    "clientID": holding.clientID,
                    "fundCode": holding.fundCode,
                    "fundName": holding.fundName,
                    "purchaseDate": ISO8601DateFormatter().string(from: holding.purchaseDate),
                    "purchaseAmount": holding.purchaseAmount,
                    "purchaseShares": holding.purchaseShares,
                    "currentNav": holding.currentNav,
                    "isPinned": holding.isPinned,
                    "remarks": holding.remarks
                ]
                
                holdingDict["navDate"] = ISO8601DateFormatter().string(from: holding.navDate)
                
                if let pinnedTimestamp = holding.pinnedTimestamp {
                    holdingDict["pinnedTimestamp"] = ISO8601DateFormatter().string(from: pinnedTimestamp)
                }
                
                return holdingDict
            },
            "username": username
        ]
        
        guard let url = URL(string: "\(baseURL)/api/holdings/upload") else {
            setAlertMessage("服务器地址错误")
            isUploading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        } catch {
            setAlertMessage("数据编码失败: \(error.localizedDescription)")
            isUploading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard response.statusCode == 200 else {
                    if let errorResponse = try? JSONDecoder().decode([String: String].self, from: output.data),
                       let errorMessage = errorResponse["error"] {
                        throw NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    } else {
                        throw NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "上传失败，服务器错误: \(response.statusCode)"])
                    }
                }
                
                return output.data
            }
            .decode(type: CloudSyncResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isUploading = false
                self.syncMessage = ""
                if case .failure(let error) = completion {
                    self.setAlertMessage("上传失败: \(error.localizedDescription)")
                }
            } receiveValue: { response in
                if response.success {
                    self.setAlertMessage("上传成功！共上传 \(response.uploadedCount ?? 0) 条持仓记录")
                } else {
                    self.setAlertMessage("上传失败: \(response.error ?? "未知错误")")
                }
            }
            .store(in: &cancellables)
    }
    
    func downloadHoldingsFromCloud(authService: AuthService, dataManager: DataManager) {
        guard let token = authService.authToken, let username = authService.currentUser?.username else {
            setAlertMessage("请先登录")
            return
        }
        
        isDownloading = true
        syncMessage = "正在下载持仓数据..."
        
        print("开始下载持仓数据，用户名: \(username)")
        
        guard let url = URL(string: "\(baseURL)/api/holdings/download") else {
            setAlertMessage("服务器地址错误")
            isDownloading = false
            syncMessage = ""
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ["username": username]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("请求体准备完成: \(requestBody)")
        } catch {
            setAlertMessage("请求数据编码失败")
            isDownloading = false
            syncMessage = ""
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                print("收到服务器响应")
                
                guard let response = output.response as? HTTPURLResponse else {
                    print("响应类型错误")
                    throw URLError(.badServerResponse)
                }
                
                print("HTTP状态码: \(response.statusCode)")
                
                guard response.statusCode == 200 else {
                    if let errorResponse = try? JSONDecoder().decode([String: String].self, from: output.data),
                       let errorMessage = errorResponse["error"] {
                        print("服务器返回错误: \(errorMessage)")
                        throw NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    } else {
                        let errorMsg = "下载失败，服务器错误: \(response.statusCode)"
                        print(errorMsg)
                        throw NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                    }
                }
                
                print("响应数据大小: \(output.data.count) 字节")
                if let rawString = String(data: output.data, encoding: .utf8) {
                    print("原始响应数据: \(rawString.prefix(500))...")
                }
                
                return output.data
            }
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isDownloading = false
                self.syncMessage = ""
                if case .failure(let error) = completion {
                    print("下载完成但失败: \(error)")
                    self.setAlertMessage("下载失败: \(error.localizedDescription)")
                }
            } receiveValue: { data in
                print("开始解析响应数据")
                self.parseDownloadedData(data, dataManager: dataManager)
            }
            .store(in: &cancellables)
    }
    
    private func parseDownloadedData(_ data: Data, dataManager: DataManager) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("成功解析为JSON对象")
                print("JSON键: \(json.keys)")
                
                if let success = json["success"] as? Bool {
                    print("success字段: \(success)")
                    
                    if success {
                        if let holdingsArray = json["holdings"] as? [[String: Any]] {
                            print("找到持仓数组，数量: \(holdingsArray.count)")
                            
                            if holdingsArray.count > 0 {
                                print("第一条持仓数据示例: \(holdingsArray[0])")
                            }
                            
                            let downloadedHoldings = self.parseHoldingsFromArray(holdingsArray)
                            dataManager.holdings = downloadedHoldings
                            dataManager.saveData()
                            self.setAlertMessage("下载成功！共下载 \(downloadedHoldings.count) 条持仓记录")
                            return
                        } else {
                            print("未找到holdings数组或格式不正确")
                        }
                    } else {
                        let errorMsg = json["error"] as? String ?? "未知错误"
                        print("服务器返回success: false, 错误: \(errorMsg)")
                        self.setAlertMessage("下载失败: \(errorMsg)")
                        return
                    }
                } else {
                    print("JSON中没有success字段")
                }
            }

            print("尝试使用JSONDecoder解析")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                print("解析日期字符串: \(dateString)")

                let isoFormatterWithFractional = ISO8601DateFormatter()
                isoFormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let isoFormatterWithoutFractional = ISO8601DateFormatter()
                isoFormatterWithoutFractional.formatOptions = [.withInternetDateTime]
                
                let formatter1 = DateFormatter()
                formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                formatter1.locale = Locale(identifier: "en_US_POSIX")
                
                let formatter2 = DateFormatter()
                formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter2.locale = Locale(identifier: "en_US_POSIX")
                
                let formatter3 = DateFormatter()
                formatter3.dateFormat = "yyyy-MM-dd"
                formatter3.locale = Locale(identifier: "en_US_POSIX")

                if let date = isoFormatterWithFractional.date(from: dateString) {
                    print("成功解析日期: \(date)")
                    return date
                }
                if let date = isoFormatterWithoutFractional.date(from: dateString) {
                    print("成功解析日期: \(date)")
                    return date
                }
                if let date = formatter1.date(from: dateString) {
                    print("成功解析日期: \(date)")
                    return date
                }
                if let date = formatter2.date(from: dateString) {
                    print("成功解析日期: \(date)")
                    return date
                }
                if let date = formatter3.date(from: dateString) {
                    print("成功解析日期: \(date)")
                    return date
                }
                
                print("无法解析日期字符串: \(dateString)")
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期字符串: \(dateString)")
            }
            
            let response = try decoder.decode(CloudSyncResponse.self, from: data)
            
            if response.success, let downloadedHoldings = response.holdings {
                dataManager.holdings = downloadedHoldings
                dataManager.saveData()
                self.setAlertMessage("下载成功！共下载 \(downloadedHoldings.count) 条持仓记录")
            } else {
                self.setAlertMessage("下载失败: \(response.error ?? "未知错误")")
            }
        } catch {
            print("JSON解析错误: \(error)")
            print("错误类型: \(type(of: error))")
            print("错误详情: \(error.localizedDescription)")

            self.manualParseDownloadData(data, dataManager: dataManager)
        }
    }

    private func parseHoldingsFromArray(_ holdingsArray: [[String: Any]]) -> [FundHolding] {
        var downloadedHoldings: [FundHolding] = []
        
        for (index, holdingDict) in holdingsArray.enumerated() {
            print("解析第 \(index + 1) 条持仓数据")
            if let holding = parseHoldingFromDictionary(holdingDict) {
                downloadedHoldings.append(holding)
                print("第 \(index + 1) 条持仓解析成功")
            } else {
                print("第 \(index + 1) 条持仓解析失败，数据: \(holdingDict)")
            }
        }
        
        print("总共解析成功 \(downloadedHoldings.count) 条持仓记录")
        return downloadedHoldings
    }

    private func parseHoldingFromDictionary(_ dict: [String: Any]) -> FundHolding? {
        print("开始解析单条持仓数据")
        print("可用字段: \(dict.keys)")

        guard let idString = dict["id"] as? String else {
            print("缺少id字段")
            return nil
        }
        
        guard UUID(uuidString: idString) != nil else {
            print("id格式无效: \(idString)")
            return nil
        }
        
        guard let clientName = dict["clientName"] as? String else {
            print("缺少clientName字段")
            return nil
        }
        
        guard let fundCode = dict["fundCode"] as? String else {
            print("缺少fundCode字段")
            return nil
        }
        
        print("必要字段检查通过")

        let purchaseDate = parseDate(from: dict["purchaseDate"]) ?? Date()
        let navDate = parseDate(from: dict["navDate"]) ?? Date()
        let pinnedTimestamp = parseDate(from: dict["pinnedTimestamp"])
        
        print("日期解析完成: purchaseDate=\(purchaseDate), navDate=\(navDate)")
        
        let purchaseAmount = parseDouble(from: dict["purchaseAmount"]) ?? 0.0
        let purchaseShares = parseDouble(from: dict["purchaseShares"]) ?? 0.0
        let currentNav = parseDouble(from: dict["currentNav"]) ?? 0.0
        
        print("数字解析完成: purchaseAmount=\(purchaseAmount), purchaseShares=\(purchaseShares), currentNav=\(currentNav)")

        let isPinned = dict["isPinned"] as? Bool ?? false

        let clientID = dict["clientID"] as? String ?? ""
        let fundName = dict["fundName"] as? String ?? ""
        let remarks = dict["remarks"] as? String ?? ""

        let holding = FundHolding(
            clientName: clientName,
            clientID: clientID,
            fundCode: fundCode,
            purchaseAmount: purchaseAmount,
            purchaseShares: purchaseShares,
            purchaseDate: purchaseDate,
            remarks: remarks,
            fundName: fundName,
            currentNav: currentNav,
            navDate: navDate,
            isValid: true,
            isPinned: isPinned,
            pinnedTimestamp: pinnedTimestamp
        )
        
        print("FundHolding对象创建成功")
        return holding
    }

    private func manualParseDownloadData(_ data: Data, dataManager: DataManager) {
        print("开始手动解析数据")
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("手动解析 - JSON结构: \(json.keys)")
                
                if let success = json["success"] as? Bool, success {
                    print("手动解析 - success为true")
                    
                    if let holdingsArray = json["holdings"] as? [[String: Any]] {
                        print("手动解析 - 找到持仓数组，数量: \(holdingsArray.count)")
                        
                        var downloadedHoldings: [FundHolding] = []
                        
                        for (index, holdingDict) in holdingsArray.enumerated() {
                            print("手动解析 - 第 \(index) 条持仓: \(holdingDict.keys)")
                            if let holding = parseHoldingFromDictionary(holdingDict) {
                                downloadedHoldings.append(holding)
                            } else {
                                print("手动解析 - 第 \(index) 条持仓解析失败")
                            }
                        }
                        
                        dataManager.holdings = downloadedHoldings
                        dataManager.saveData()
                        self.setAlertMessage("下载成功！共下载 \(downloadedHoldings.count) 条持仓记录")
                    } else {
                        print("手动解析 - 没有holdings字段或格式错误")
                        self.setAlertMessage("下载失败: 数据格式错误 - 缺少holdings字段")
                    }
                } else {
                    let errorMsg = json["error"] as? String ?? "未知错误"
                    print("手动解析 - success为false, 错误: \(errorMsg)")
                    self.setAlertMessage("下载失败: \(errorMsg)")
                }
            } else {
                print("手动解析 - 无法解析为JSON对象")
                self.setAlertMessage("下载失败: 数据格式错误")
            }
        } catch {
            print("手动解析错误: \(error)")
            if let rawString = String(data: data, encoding: .utf8) {
                print("原始响应数据: \(rawString)")
            }
            self.setAlertMessage("数据解析失败: \(error.localizedDescription)")
        }
    }

    private func parseDate(from value: Any?) -> Date? {
        guard let dateValue = value else {
            print("日期值为nil")
            return nil
        }
        
        if let date = dateValue as? Date {
            print("已经是Date类型: \(date)")
            return date
        }
        
        guard let dateString = dateValue as? String else {
            print("日期值不是String类型: \(type(of: dateValue))")
            return nil
        }
        
        print("解析日期字符串: \(dateString)")

        let isoFormatterWithFractional = ISO8601DateFormatter()
        isoFormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let isoFormatterWithoutFractional = ISO8601DateFormatter()
        isoFormatterWithoutFractional.formatOptions = [.withInternetDateTime]
        
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter2.locale = Locale(identifier: "en_US_POSIX")
        
        let formatter3 = DateFormatter()
        formatter3.dateFormat = "yyyy-MM-dd"
        formatter3.locale = Locale(identifier: "en_US_POSIX")

        if let date = isoFormatterWithFractional.date(from: dateString) {
            print("成功解析日期: \(date)")
            return date
        }
        if let date = isoFormatterWithoutFractional.date(from: dateString) {
            print("成功解析日期: \(date)")
            return date
        }
        if let date = formatter1.date(from: dateString) {
            print("成功解析日期: \(date)")
            return date
        }
        if let date = formatter2.date(from: dateString) {
            print("成功解析日期: \(date)")
            return date
        }
        if let date = formatter3.date(from: dateString) {
            print("成功解析日期: \(date)")
            return date
        }
        
        print("无法解析日期字符串: \(dateString)")
        return nil
    }

    private func parseDouble(from value: Any?) -> Double? {
        guard let numValue = value else {
            print("数字值为nil")
            return nil
        }
        
        switch numValue {
        case let doubleValue as Double:
            print("Double类型: \(doubleValue)")
            return doubleValue
        case let floatValue as Float:
            print("Float类型: \(floatValue)")
            return Double(floatValue)
        case let intValue as Int:
            print("Int类型: \(intValue)")
            return Double(intValue)
        case let stringValue as String:
            print("String类型: \(stringValue)")
            return Double(stringValue)
        case let decimalValue as NSNumber:
            print("NSNumber类型: \(decimalValue)")
            return decimalValue.doubleValue
        default:
            print("未知数字类型: \(type(of: numValue)), 值: \(numValue)")
            return nil
        }
    }
    
    func setAlertMessage(_ message: String) {
        syncAlertMessage = message
        showSyncAlert = true
        print("设置警告消息: \(message)")
    }
}

struct FoundationHolding: Codable {
    let id: String?
    let clientName: String?
    let clientID: String?
    let fundCode: String?
    let fundName: String?
    let purchaseDate: String?
    let purchaseAmount: Double?
    let purchaseShares: Double?
    let currentNav: Double?
    let navDate: String?
    let isPinned: Bool?
    let pinnedTimestamp: String?
    let remarks: String?
    
    func toFundHolding() -> FundHolding? {
        guard let idString = id,
              let _ = UUID(uuidString: idString),
              let clientName = clientName,
              let fundCode = fundCode else {
            return nil
        }

        let purchaseDateValue: Date
        if let purchaseDateString = purchaseDate,
           let date = ISO8601DateFormatter().date(from: purchaseDateString) {
            purchaseDateValue = date
        } else {
            purchaseDateValue = Date()
        }
        
        let navDateValue: Date
        if let navDateString = navDate,
           let date = ISO8601DateFormatter().date(from: navDateString) {
            navDateValue = date
        } else {
            navDateValue = Date()
        }
        
        var pinnedTimestampValue: Date?
        if let pinnedTimestampString = pinnedTimestamp,
           let date = ISO8601DateFormatter().date(from: pinnedTimestampString) {
            pinnedTimestampValue = date
        }

        return FundHolding(
            clientName: clientName,
            clientID: clientID ?? "",
            fundCode: fundCode,
            purchaseAmount: purchaseAmount ?? 0.0,
            purchaseShares: purchaseShares ?? 0.0,
            purchaseDate: purchaseDateValue,
            remarks: remarks ?? "",
            fundName: fundName ?? "",
            currentNav: currentNav ?? 0.0,
            navDate: navDateValue,
            isValid: true,
            isPinned: isPinned ?? false,
            pinnedTimestamp: pinnedTimestampValue
        )
    }
}

struct CloudSyncResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
    let uploadedCount: Int?
    let holdings: [FundHolding]?
    
    enum CodingKeys: String, CodingKey {
        case success, message, error
        case uploadedCount = "uploaded_count"
        case holdings
    }
}
