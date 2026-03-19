//
//  HomeViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads featured products for the home page.
//

import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var featuredProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = VercelService.shared

    func loadFeatured() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let all = try await api.fetchProducts()
            featuredProducts = all.filter { $0.isFeatured }
        } catch {
            featuredProducts = []
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}
