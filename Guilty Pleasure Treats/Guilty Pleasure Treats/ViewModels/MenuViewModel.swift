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
    /// Cached ordered category names for menu sections and chips. Only updated in loadMenu/useSampleMenu so chip order stays fixed.
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
            if all.isEmpty {
                useSampleMenu()
            }
        } catch {
            useSampleMenu()
            if !VercelService.isConfigured {
                errorMessage = nil
            } else {
                errorMessage = "Showing sample menu. Pull down to refresh."
            }
        }
        isLoading = false
    }

    /// Show sample menu so you can see how it looks when API has no products or is unavailable.
    private func useSampleMenu() {
        if categoryOrder.isEmpty { categoryOrder = Self.defaultCategories }
        let categories = categoryOrder
        let samples = SampleDataService.sampleProducts.enumerated().map { index, p in
            var product = p
            product.id = "sample-\(index)"
            return product
        }
        var grouped: [String: [Product]] = [:]
        for cat in categories {
            grouped[cat] = samples.filter { $0.category == cat && !$0.isSoldOut }
        }
        productsByCategory = grouped
        orderedCategoryNames = Self.computeOrderedCategoryNames(categoryOrder: categoryOrder, productsByCategory: grouped)
    }

    /// One-time computation so chip/section order is stable and only changes when menu is loaded.
    private static func computeOrderedCategoryNames(categoryOrder: [String], productsByCategory: [String: [Product]]) -> [String] {
        let withProducts = categoryOrder.filter { (productsByCategory[$0] ?? []).isEmpty == false }
        let others = productsByCategory.keys.filter { !categoryOrder.contains($0) }.sorted()
        return withProducts + others
    }
}
