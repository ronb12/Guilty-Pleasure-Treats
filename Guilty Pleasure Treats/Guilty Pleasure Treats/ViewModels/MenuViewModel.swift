//
//  MenuViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads products by category for Menu screen.
//

import Foundation
import Combine

@MainActor
final class MenuViewModel: ObservableObject {
    @Published var productsByCategory: [String: [Product]] = [:]
    /// Category order from API (owner-managed); used for menu section order.
    @Published var categoryOrder: [String] = []
    /// Cached ordered category names for menu sections and chips. Updated in `loadMenu`.
    @Published var orderedCategoryNames: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let api = VercelService.shared
    private static let defaultCategories = ProductCategory.allCases.map(\.rawValue)
    
    func loadMenu() async {
        isLoading = true
        errorMessage = nil
        do {
            let categories: [String]
            if let cats = try? await api.fetchProductCategories(), !cats.isEmpty {
                categoryOrder = cats.sorted { $0.displayOrder < $1.displayOrder }.map(\.name)
                categories = categoryOrder
            } else {
                categoryOrder = Self.defaultCategories
                categories = Self.defaultCategories
            }
            let all = try await api.fetchProducts()
            var grouped: [String: [Product]] = [:]
            for cat in categories {
                grouped[cat] = all.filter { $0.category == cat && !$0.isSoldOut }
            }
            let otherCats = Set(all.map(\.category)).subtracting(Set(categories))
            for cat in otherCats {
                grouped[cat] = all.filter { $0.category == cat && !$0.isSoldOut }
            }
            productsByCategory = grouped
            orderedCategoryNames = Self.computeOrderedCategoryNames(categoryOrder: categoryOrder, productsByCategory: grouped)
        } catch {
            productsByCategory = [:]
            orderedCategoryNames = []
            if VercelService.isConfigured {
                errorMessage = "Couldn’t load the menu. Pull down to try again."
            } else {
                errorMessage = nil
            }
        }
        isLoading = false
    }

    /// One-time computation so chip/section order is stable and only changes when menu is loaded.
    private static func computeOrderedCategoryNames(categoryOrder: [String], productsByCategory: [String: [Product]]) -> [String] {
        let withProducts = categoryOrder.filter { (productsByCategory[$0] ?? []).isEmpty == false }
        let others = productsByCategory.keys.filter { !categoryOrder.contains($0) }.sorted()
        return withProducts + others
    }
}
