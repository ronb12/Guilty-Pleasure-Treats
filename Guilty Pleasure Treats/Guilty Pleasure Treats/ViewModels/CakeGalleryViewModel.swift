//
//  CakeGalleryViewModel.swift
//  Guilty Pleasure Treats
//
//  Loads cake gallery and handles "order this design" (saves as AI design and adds to cart).
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

    func orderItem(_ item: GalleryCakeItem) async {
        errorMessage = nil
        let price = item.price ?? 35.0
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
