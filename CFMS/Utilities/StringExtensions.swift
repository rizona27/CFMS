//String 类型的扩展，其核心作用是提供字符串净化和格式化处理工具，主要针对用户输入场景，以确保数据格式的正确性。
import Foundation
extension String {
    func filterNumericsAndDecimalPoint() -> String {
        var filtered = ""
        var hasDecimal = false

        for char in self {
            if char.isNumber {
                filtered.append(char)
            } else if char == "." && !hasDecimal {
                if !filtered.isEmpty {
                    filtered.append(char)
                    hasDecimal = true
                }
            }
        }
        return filtered
    }

    func filterAllowedNameCharacters() -> String {
        var result = ""
        var lastCharWasSpace = false

        for char in self {
            let isHan = String(char).range(of: "\\p{Han}", options: .regularExpression) != nil
            let isLetter = char.isASCII && char.isLetter
            let isSpace = char == " "

            if isHan || isLetter {
                result.append(char)
                lastCharWasSpace = false
            } else if isSpace && !lastCharWasSpace && !result.isEmpty {
                result.append(char)
                lastCharWasSpace = true
            }
        }
        return result.trimmingTrailingSpaces()
    }

    func trimmingTrailingSpaces() -> String {
        var newString = self
        while newString.hasSuffix(" ") {
            newString.removeLast()
        }
        return newString
    }
}
