//
//  Item.swift
//  Pantry
//
//  Created by Joseph O'Brien on 3/6/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var name: String
    var quantity: Int
    var expirationDate: Date?
    var lastPurchased: Date
    var purchaseHistory: [Date]
    var usageHistory: [Date]
    var notificationEnabled: Bool
    
    init(name: String, quantity: Int = 1, expirationDate: Date? = nil) {
        self.name = name
        self.quantity = quantity
        self.expirationDate = expirationDate
        self.lastPurchased = Date()
        self.purchaseHistory = [Date()]
        self.usageHistory = []
        self.notificationEnabled = expirationDate != nil
    }
    
    func recordPurchase() {
        lastPurchased = Date()
        purchaseHistory.append(lastPurchased)
    }
    
    func recordUsage() {
        quantity = max(0, quantity - 1)
        usageHistory.append(Date())
    }
    
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
    }
}
