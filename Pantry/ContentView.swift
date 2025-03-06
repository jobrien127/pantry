//
//  ContentView.swift
//  Pantry
//
//  Created by Joseph O'Brien on 3/6/25.
//

import SwiftUI
import SwiftData
import Observation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddItem = false
    @State private var showingSuggestions = false
    
    private let viewModel: PantryViewModel
    
    init(modelContext: ModelContext) {
        self.viewModel = PantryViewModel(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationSplitView {
            List {
                Section("Inventory") {
                    ForEach(items) { item in
                        NavigationLink {
                            ItemDetailView(item: item, viewModel: viewModel)
                        } label: {
                            ItemRowView(item: item)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddItem = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSuggestions = true }) {
                        Label("Suggestions", systemImage: "lightbulb")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSuggestions) {
            SuggestionsView(suggestions: viewModel.getSuggestions())
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct ItemRowView: View {
    let item: Item
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(item.name)
                .font(.headline)
            HStack {
                Text("Quantity: \(item.quantity)")
                    .font(.subheadline)
                if let daysUntilExpiration = item.daysUntilExpiration {
                    Spacer()
                    Text(daysUntilExpiration <= 0 ? "Expired" : "Expires in \(daysUntilExpiration) days")
                        .font(.subheadline)
                        .foregroundColor(daysUntilExpiration <= 3 ? .red : .secondary)
                }
            }
        }
    }
}

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: PantryViewModel
    
    @State private var name = ""
    @State private var quantity = 1
    @State private var expirationDate: Date? = nil
    @State private var hasExpirationDate = false
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Item Name", text: $name)
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                Toggle("Has Expiration Date", isOn: $hasExpirationDate)
                if hasExpirationDate {
                    DatePicker("Expiration Date",
                              selection: Binding(
                                get: { expirationDate ?? Date() },
                                set: { expirationDate = $0 }
                              ),
                              in: Date()...)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") {
                    addItem()
                    dismiss()
                }
                .disabled(name.isEmpty)
            )
        }
    }
    
    private func addItem() {
        let item = Item(
            name: name,
            quantity: quantity,
            expirationDate: hasExpirationDate ? expirationDate : nil
        )
        viewModel.modelContext.insert(item)
        if hasExpirationDate {
            viewModel.scheduleExpirationNotification(for: item)
        }
    }
}

struct ItemDetailView: View {
    @Bindable var item: Item
    let viewModel: PantryViewModel
    
    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Name", value: item.name)
                LabeledContent("Quantity", value: "\(item.quantity)")
                if let expirationDate = item.expirationDate {
                    LabeledContent("Expires", value: expirationDate.formatted(date: .long, time: .omitted))
                }
            }
            
            Section {
                Button("Record Purchase") {
                    item.recordPurchase()
                }
                Button("Record Usage") {
                    item.recordUsage()
                }
            }
            
            Section("History") {
                Text("Purchased \(item.purchaseHistory.count) times")
                Text("Used \(item.usageHistory.count) times")
                Text("Last purchased: \(item.lastPurchased.formatted(date: .long, time: .omitted))")
            }
        }
        .navigationTitle(item.name)
    }
}

struct SuggestionsView: View {
    @Environment(\.dismiss) private var dismiss
    let suggestions: [String]
    
    var body: some View {
        NavigationView {
            List {
                if suggestions.isEmpty {
                    Text("No suggestions available yet. Keep using the app to get personalized recommendations!")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Text(suggestion)
                    }
                }
            }
            .navigationTitle("Suggested Items")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

#Preview {
    ContentView(modelContext: try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext)
        .modelContainer(for: Item.self, inMemory: true)
}
