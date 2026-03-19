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
    @Published var upcomingEvents: [Event] = []
    @Published var reviews: [Review] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = VercelService.shared

    func loadFeatured() async {
        isLoading = true
        errorMessage = nil
        do {
            async let products: () = loadFeaturedProducts()
            async let events: () = loadEvents()
            async let revs: () = loadReviews()
            _ = await (products, events, revs)
        }
        isLoading = false
    }

    private func loadFeaturedProducts() async {
        do {
            featuredProducts = try await api.fetchProducts(featuredOnly: true)
        } catch {
            featuredProducts = []
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    private func loadEvents() async {
        do {
            upcomingEvents = try await api.fetchEvents()
        } catch {
            upcomingEvents = []
        }
    }

    private func loadReviews() async {
        do {
            reviews = try await api.fetchReviews()
        } catch {
            reviews = []
        }
    }
}
