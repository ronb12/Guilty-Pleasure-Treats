//
//  HomeViewModel.swift
//  Guilty Pleasure Treats
//
//  Fetches featured products and drives Home screen.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var featuredProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebase = FirebaseService.shared
    
    func loadFeatured() async {
        isLoading = true
        errorMessage = nil
        do {
            featuredProducts = try await firebase.fetchProducts(featuredOnly: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
