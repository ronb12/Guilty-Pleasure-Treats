//
//  FavoritesManager.swift
//  Guilty Pleasure Treats
//
//  Persists favorite product IDs in UserDefaults for "Save for later" / Favorites.
//

import Foundation
import Combine

final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    private let key = "favoriteProductIds"

    @Published private(set) var favoriteIds: Set<String> = []

    private init() {
        load()
    }

    private func load() {
        guard let raw = UserDefaults.standard.array(forKey: key) as? [String] else { return }
        favoriteIds = Set(raw)
    }

    private func save() {
        UserDefaults.standard.set(Array(favoriteIds), forKey: key)
    }

    func isFavorite(productId: String?) -> Bool {
        guard let id = productId, !id.isEmpty else { return false }
        return favoriteIds.contains(id)
    }

    func toggle(productId: String?) {
        guard let id = productId, !id.isEmpty else { return }
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
        } else {
            favoriteIds.insert(id)
        }
        save()
    }

    func favoriteProducts(from all: [Product]) -> [Product] {
        all.filter { isFavorite(productId: $0.id) }
    }
}
