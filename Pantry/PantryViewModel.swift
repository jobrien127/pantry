import SwiftUI
import SwiftData
import UserNotifications

@Observable
class PantryViewModel {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupNotifications()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
    
    func scheduleExpirationNotification(for item: Item) {
        guard item.notificationEnabled,
              let expirationDate = item.expirationDate else { return }
        
        // Schedule notification 3 days before expiration
        let notificationDate = Calendar.current.date(byAdding: .day, value: -3, to: expirationDate)
        guard let notificationDate = notificationDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Item Expiring Soon"
        content.body = "\(item.name) will expire in 3 days"
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: "expiration-\(item.name)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func getSuggestions() -> [String] {
        do {
            let descriptor = FetchDescriptor<Item>()
            let items = try modelContext.fetch(descriptor)
            
            // Analyze purchase patterns
            let frequentItems = Dictionary(grouping: items) { $0.name }
                .mapValues { items in
                    let purchases = items.first?.purchaseHistory.count ?? 0
                    let daysSinceLastPurchase = Calendar.current.dateComponents(
                        [.day],
                        from: items.first?.lastPurchased ?? Date(),
                        to: Date()
                    ).day ?? 0
                    return (purchases: purchases, daysSince: daysSinceLastPurchase)
                }
            
            // Suggest items that are:
            // 1. Frequently purchased (more than 3 times)
            // 2. Haven't been purchased recently (over 2 weeks)
            return frequentItems
                .filter { $0.value.purchases >= 3 && $0.value.daysSince >= 14 }
                .map { $0.key }
                .sorted()
        } catch {
            print("Error fetching items for suggestions: \(error)")
            return []
        }
    }
}