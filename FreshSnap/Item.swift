//
//  Item.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 21/10/2026.
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
