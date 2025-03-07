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
                    NavigationLink {
                        AddItemView(viewModel: viewModel)
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { 
                        DispatchQueue.main.async {
                            showingSuggestions = true
                        }
                    }) {
                        Label("Suggestions", systemImage: "lightbulb")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $showingSuggestions) {
            SuggestionsView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $showError, presenting: viewModel.error) { _ in
            Button("OK") { }
        } message: { error in
            Text(error.localizedDescription)
        }
        .onChange(of: viewModel.error) { _, error in
            DispatchQueue.main.async {
                showError = error != nil
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        let itemsToDelete = offsets.map { items[$0] }
        viewModel.deleteItems(itemsToDelete)
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
                    let daysText = daysUntilExpiration <= 0 
                        ? "Expired" 
                        : "Expires in \(max(0, daysUntilExpiration)) days"
                    Text(daysText)
                        .font(.subheadline)
                        .foregroundColor(daysUntilExpiration <= 3 ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: PantryViewModel
    
    @State private var name: String = ""
    @State private var quantity = 1
    @State private var expirationDate: Date? = nil
    @State private var hasExpirationDate = false
    @State private var showError = false
    
    var body: some View {
        Form {
            TextField("Item Name", text: $name)
            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
            Toggle("Has Expiration Date", isOn: $hasExpirationDate)
            if hasExpirationDate {
                DatePicker(
                    "Expiration Date",
                    selection: Binding(
                        get: { expirationDate ?? Calendar.current.startOfDay(for: Date()) },
                        set: { expirationDate = Calendar.current.startOfDay(for: $0) }
                    ),
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }
        }
        .navigationTitle("Add Item")
        .navigationBarItems(
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
            DispatchQueue.main.async {
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
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ItemDetailView: View {
    @Bindable var item: Item
    @ObservedObject var viewModel: PantryViewModel
    @State private var showError = false
    @State private var error: Error?
    
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
                    do {
                        item.recordPurchase()
                        try viewModel.modelContext.save()
                        if item.notificationEnabled {
                            viewModel.scheduleExpirationNotification(for: item)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.error = error
                            showError = true
                        }
                    }
                }
                Button("Record Usage") {
                    do {
                        item.recordUsage()
                        try viewModel.modelContext.save()
                    } catch {
                        DispatchQueue.main.async {
                            self.error = error
                            showError = true
                        }
                    }
                }
            }
            
            Section("History") {
                Text("Purchased \(item.purchaseHistory.count) times")
                Text("Used \(item.usageHistory.count) times")
                Text("Last purchased: \(item.lastPurchased.formatted(date: .long, time: .omitted))")
            }
        }
        .navigationTitle(item.name)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            if let error = error {
                Text("An error occurred: \(error.localizedDescription)")
            } else if let viewModelError = viewModel.error {
                Text(viewModelError.localizedDescription)
            } else {
                Text("An unknown error occurred")
            }
        }
        .onChange(of: viewModel.error) { _, error in
            DispatchQueue.main.async {
                showError = error != nil
            }
        }
    }
}

struct SuggestionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PantryViewModel
    @State private var showError = false
    
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
            .navigationBarItems(trailing: Button("Done") { 
                DispatchQueue.main.async {
                    dismiss()
                }
            })
            .alert("Error", isPresented: $showError, presenting: viewModel.error) { _ in
                Button("OK") { }
            } message: { error in
                Text(error.localizedDescription)
            }
            .onChange(of: viewModel.error) { _, error in
                DispatchQueue.main.async {
                    showError = error != nil
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Better handling of navigation constraints
    }
}

#Preview {
    ContentView(modelContext: try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext)
        .modelContainer(for: Item.self, inMemory: true)
}
