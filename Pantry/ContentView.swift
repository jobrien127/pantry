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
    @State private var error: Error?
    @State private var showError = false
    
    @StateObject private var viewModel: PantryViewModel
    
    init(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\Item.name)])
        _items = Query(descriptor)
        _viewModel = StateObject(wrappedValue: PantryViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationSplitView {
            List {
                Section("Inventory") {
                    if items.isEmpty {
                        Text("No items yet. Tap + to add items to your pantry.")
                            .foregroundColor(.secondary)
                    } else {
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
            SuggestionsView(viewModel: viewModel)
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
    @ObservedObject var viewModel: PantryViewModel
    
    @State private var name = ""
    @State private var quantity = 1
    @State private var expirationDate: Date? = nil
    @State private var hasExpirationDate = false
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Item Name", text: $name)
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                Toggle("Has Expiration Date", isOn: $hasExpirationDate)
                if hasExpirationDate {
                    DatePicker("Expiration Date",
                              selection: Binding(
                                get: { expirationDate ?? Calendar.current.startOfDay(for: Date()) },
                                set: { expirationDate = Calendar.current.startOfDay(for: $0) }
                              ),
                              in: Calendar.current.startOfDay(for: Date())...,
                              displayedComponents: .date)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") {
                    addItem()
                }
                .disabled(name.isEmpty)
            )
            .alert("Error", isPresented: $showError, presenting: viewModel.error) { _ in
                Button("OK") { }
            } message: { error in
                Text(error.localizedDescription)
            }
            .onChange(of: viewModel.error) { _, error in
                showError = error != nil
            }
        }
    }
    
    private func addItem() {
        let item = Item(
            name: name,
            quantity: quantity,
            expirationDate: hasExpirationDate ? expirationDate : nil
        )
        viewModel.addItem(item)
        
        // Only dismiss if there's no error
        if viewModel.error == nil {
            dismiss()
        }
    }
}

struct ItemDetailView: View {
    @Bindable var item: Item
    @ObservedObject var viewModel: PantryViewModel
    
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
    @ObservedObject var viewModel: PantryViewModel
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.suggestions.isEmpty {
                    Text("No suggestions available yet. Keep using the app to get personalized recommendations!")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
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
