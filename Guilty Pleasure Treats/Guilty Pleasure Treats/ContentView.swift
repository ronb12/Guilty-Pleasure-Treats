//
//  ContentView.swift
//  Guilty Pleasure Treats
//
//  Created by Ronell J Bradley on 3/15/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AICakeDesignerView()
                    } label: {
                        Label("AI Cake Designer", systemImage: "wand.and.stars")
                            .font(.headline)
                    }
                } header: {
                    Text("Guilty Pleasure Treats")
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                            .font(.headline)
                    }
                } header: {
                    Text("App")
                }
                Section("Legal") {
                    NavigationLink("Privacy Policy") {
                        DocumentView(title: "Privacy Policy", markdown: LegalContent.privacyPolicyMarkdown)
                    }
                    NavigationLink("Terms of Service") {
                        DocumentView(title: "Terms of Service", markdown: LegalContent.termsOfServiceMarkdown)
                    }
                }
                Section("Items") {
                    ForEach(items) { item in
                        NavigationLink {
                            Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                        } label: {
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
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

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
