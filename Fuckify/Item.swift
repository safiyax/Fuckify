//
//  Item.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2025-11-08.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date()

    init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }
}
