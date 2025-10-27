//
//  Item.swift
//  CFMS
//
//  Created by 倪志浩 on 2025/10/27.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
