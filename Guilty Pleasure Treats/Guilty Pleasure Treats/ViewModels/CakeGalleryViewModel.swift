//
//  CakeGalleryViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads gallery; priced items add AI design to cart; unpriced items use Request a quote (Contact).
//

import Foundation
import Combine

@MainActor
final class CakeGalleryViewModel: ObservableObject {
    @Published var items: [GalleryCakeItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var addedToCart = false

    private let api = VercelService.shared
    private let cart = CartManager.shared
    private let auth = AuthService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await api.fetchGalleryCakes()
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }

    /// Adds priced gallery design to cart as an AI cake design line. Call only when `item.price != nil`.
    func orderItem(_ item: GalleryCakeItem) async {
        errorMessage = nil
        guard let price = item.price else {
            errorMessage = "This item doesn’t have a set price. Use Request a quote."
            return
        }
        var order = AICakeDesignOrder(
            id: nil,
            userId: auth.currentUser?.uid,
            size: "As shown",
            flavor: "Custom",
            frosting: "",
            designPrompt: item.title + (item.description.map { " · \($0)" } ?? ""),
            generatedImageURL: item.imageUrl,
            price: price,
            orderId: nil,
            createdAt: nil
        )
        do {
            let docId = try await api.saveAICakeDesignOrder(order)
            order.id = docId
            cart.addAICakeDesign(order)
            addedToCart = true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
        }
    }
}
