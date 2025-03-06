import SwiftUI
import SwiftData
import UserNotifications
import Combine

enum PantryError: LocalizedError, Equatable {
    case duplicateItem(name: String)
    case invalidItem
    case notificationFailure(Error)
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem(let name):
            return "An item named '\(name)' already exists"
        case .invalidItem:
            return "Invalid item data"
        case .notificationFailure(let error):
            return "Notification error: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: PantryError, rhs: PantryError) -> Bool {
        switch (lhs, rhs) {
        case (.duplicateItem(let lName), .duplicateItem(let rName)):
            return lName == rName
        case (.invalidItem, .invalidItem):
            return true
        case (.notificationFailure(let lError), .notificationFailure(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        default:
            return false
        }
    }
}

class PantryViewModel: ObservableObject {
    let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var notificationStatus: Bool = false
    @Published private(set) var error: PantryError?
    
    private let itemSubject = PassthroughSubject<Item, Never>()
    private let errorSubject = PassthroughSubject<PantryError, Never>()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupNotifications()
        setupSuggestionUpdates()
        setupErrorHandling()
    }
    
    private func setupErrorHandling() {
        errorSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error
                // Auto-clear error after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.error = nil
                }
            }
            .store(in: &cancellables)
    }
    
    func addItem(_ item: Item) {
        do {
            // Check for duplicate
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { item in item.name == item.name },
                sortBy: [SortDescriptor(\Item.name)]
            )
            let existing = try modelContext.fetch(descriptor)
            
            guard existing.isEmpty else {
                errorSubject.send(.duplicateItem(name: item.name))
                return
            }
            
            modelContext.insert(item)
            itemSubject.send(item)
            
            if item.notificationEnabled {
                scheduleExpirationNotification(for: item)
            }
        } catch {
            errorSubject.send(.invalidItem)
        }
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
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorSubject.send(.notificationFailure(error))
                }
            },
            receiveValue: { [weak self] granted in
                self?.notificationStatus = granted
            }
        )
        .store(in: &cancellables)
    }
    
    private func setupSuggestionUpdates() {
        // Combine item changes with timer updates
        Publishers.Merge(
            itemSubject.debounce(for: .seconds(1), scheduler: DispatchQueue.main),
            Timer.publish(every: 3600, on: .main, in: .common)
                .autoconnect()
                .map { _ in Item(name: "", quantity: 0) } // Dummy item to trigger update
        )
        .sink { [weak self] _ in
            self?.updateSuggestions()
        }
        .store(in: &cancellables)
        
        // Initial update
        updateSuggestions()
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
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorSubject.send(.notificationFailure(error))
                }
            },
            receiveValue: { }
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
            errorSubject.send(.invalidItem)
            suggestions = []
        }
    }
    
    func getSuggestions() -> [String] {
        suggestions
    }
}