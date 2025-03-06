import SwiftUI
import SwiftData
import UserNotifications
import Combine

@Observable
class PantryViewModel {
    let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    private(set) var suggestions: [String] = []
    private(set) var notificationStatus: Bool = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupNotifications()
        setupSuggestionUpdates()
    }
    
    private func setupNotifications() {
        // Check current notification settings
        Future<UNNotificationSettings, Never> { promise in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                promise(.success(settings))
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] settings in
            self?.notificationStatus = settings.authorizationStatus == .authorized
        }
        .store(in: &cancellables)
        
        // Request authorization
        Future<Bool, Error> { promise in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(granted))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error requesting notification permission: \(error)")
                }
            },
            receiveValue: { [weak self] granted in
                self?.notificationStatus = granted
            }
        )
        .store(in: &cancellables)
    }
    
    private func setupSuggestionUpdates() {
        // Initial update
        updateSuggestions()
        
        // Update suggestions every hour
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateSuggestions()
            }
            .store(in: &cancellables)
    }
    
    func scheduleExpirationNotification(for item: Item) {
        guard notificationStatus,
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
        
        Future<Void, Error> { promise in
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to schedule notification: \(error)")
                }
            },
            receiveValue: {}
        )
        .store(in: &cancellables)
    }
    
    private func updateSuggestions() {
        do {
            let descriptor = FetchDescriptor<Item>()
            let items = try modelContext.fetch(descriptor)
            
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
            
            suggestions = frequentItems
                .filter { $0.value.purchases >= 3 && $0.value.daysSince >= 14 }
                .map { $0.key }
                .sorted()
        } catch {
            print("Error fetching items for suggestions: \(error)")
            suggestions = []
        }
    }
    
    func getSuggestions() -> [String] {
        suggestions
    }
}