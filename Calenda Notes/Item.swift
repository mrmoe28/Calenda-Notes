//
//  Item.swift
//  Calenda Notes
//
//  Created by Edward Harrison on 11/29/25.
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
