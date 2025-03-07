//
//  Item.swift
//  Pantry
//
//  Created by Joseph O'Brien on 3/6/25.
//

import Foundation
import SwiftData

@Model
final class Item: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Int
    var expirationDate: Date?
    var lastPurchased: Date
    
    @Transient
    var purchaseHistory: [Date] {
        get {
            purchaseHistoryData.compactMap { date in
                guard let dateString = date,
                      !dateString.isEmpty else { return nil }
                return ISO8601DateFormatter().date(from: dateString)
            }
        }
        set {
            purchaseHistoryData = newValue.map { ISO8601DateFormatter().string(from: $0) }
        }
    }
    
    @Transient
    var usageHistory: [Date] {
        get {
            usageHistoryData.compactMap { date in
                guard let dateString = date,
                      !dateString.isEmpty else { return nil }
                return ISO8601DateFormatter().date(from: dateString)
            }
        }
        set {
            usageHistoryData = newValue.map { ISO8601DateFormatter().string(from: $0) }
        }
    }
    
    var purchaseHistoryData: [String?] = []
    var usageHistoryData: [String?] = []
    var notificationEnabled: Bool
    
    init(name: String, quantity: Int = 1, expirationDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.expirationDate = expirationDate.map { Calendar.current.startOfDay(for: $0) }
        self.lastPurchased = Calendar.current.startOfDay(for: Date())
        
        // Initialize with string values
        let todayString = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        self.purchaseHistoryData = [todayString]
        self.usageHistoryData = []
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
