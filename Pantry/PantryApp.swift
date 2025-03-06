//
//  PantryApp.swift
//  Pantry
//
//  Created by Joseph O'Brien on 3/6/25.
//

import SwiftUI
import SwiftData

@main
struct PantryApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            // Fallback to in-memory store if persistent store fails
            print("Failed to create persistent store: \(error)")
            print("Falling back to in-memory store")
            
            let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(modelContext: sharedModelContainer.mainContext)
        }
        .modelContainer(sharedModelContainer)
    }
}
