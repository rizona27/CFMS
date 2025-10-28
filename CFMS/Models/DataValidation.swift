import Foundation

enum DataError: LocalizedError {
    case fileReadError
    case dataDecodingError
    case networkError
    case invalidHoldingData
    
    var errorDescription: String? {
        switch self {
        case .fileReadError: return "文件读取失败"
        case .dataDecodingError: return "数据解析错误"
        case .networkError: return "网络连接失败"
        case .invalidHoldingData: return "持仓数据无效"
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidFundCode
    case invalidAmount
    case invalidShares
    case invalidClientInfo
    case invalidHoldingData
    
    var errorDescription: String? {
        switch self {
        case .invalidFundCode: return "基金代码无效"
        case .invalidAmount: return "购买金额无效"
        case .invalidShares: return "购买份额无效"
        case .invalidClientInfo: return "客户信息无效"
        case .invalidHoldingData: return "持仓数据无效" 
        }
    }
}
