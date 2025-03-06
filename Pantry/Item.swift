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
    @Attribute(.unique) var name: String
    var quantity: Int
    var expirationDate: Date?
    var lastPurchased: Date
    var purchaseHistory: [Date]
    var usageHistory: [Date]
    var notificationEnabled: Bool
    
    init(name: String, quantity: Int = 1, expirationDate: Date? = nil) {
        self.name = name
        self.quantity = quantity
        self.expirationDate = expirationDate.map { Calendar.current.startOfDay(for: $0) }
        self.lastPurchased = Calendar.current.startOfDay(for: Date())
        self.purchaseHistory = [Calendar.current.startOfDay(for: Date())]
        self.usageHistory = []
        self.notificationEnabled = expirationDate != nil
    }
    
    func recordPurchase() {
        let now = Calendar.current.startOfDay(for: Date())
        lastPurchased = now
        purchaseHistory.append(now)
    }
    
    func recordUsage() {
        quantity = max(0, quantity - 1)
        usageHistory.append(Calendar.current.startOfDay(for: Date()))
    }
    
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
    }
}
