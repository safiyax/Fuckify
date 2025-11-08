//
//  Item.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2025-11-08.
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
