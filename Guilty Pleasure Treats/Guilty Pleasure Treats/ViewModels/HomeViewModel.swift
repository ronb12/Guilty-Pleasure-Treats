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
    /// Admin-created promos that are active and within their date window (public `GET /api/promotions`, filtered client-side).
    @Published var activePromotions: [Promotion] = []
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
            async let promos: () = loadActivePromotions()
            async let events: () = loadEvents()
            async let revs: () = loadReviews()
            _ = await (products, promos, events, revs)
        }
        isLoading = false
    }

    private func loadFeaturedProducts() async {
        do {
            featuredProducts = try await api.fetchProducts(featuredOnly: true).filter { !$0.isUnavailableOnMenu }
        } catch {
            featuredProducts = []
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    private func loadActivePromotions() async {
        do {
            let all = try await api.fetchPromotions()
            activePromotions = all
                .filter { $0.isValidForCustomerDisplay() }
                .sorted { a, b in
                    let ad = a.createdAt ?? .distantPast
                    let bd = b.createdAt ?? .distantPast
                    return ad > bd
                }
        } catch {
            activePromotions = []
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
