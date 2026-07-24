//
//  Item.swift
//  gym_systemOS
//
//  Created by AndGP0502 on 24/7/26.
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
