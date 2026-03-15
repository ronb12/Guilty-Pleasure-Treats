//
//  CartManager.swift
//  Guilty Pleasure Treats
//
//  Global cart state: add/remove items, quantity, total. Used by Cart and Checkout.
//

import Foundation
import Combine

final class CartManager: ObservableObject {
    static let shared = CartManager()
    
    @Published private(set) var items: [CartItem] = []
    
    var isEmpty: Bool { items.isEmpty }
    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var subtotal: Double { items.reduce(0) { $0 + $1.subtotal } }
    var tax: Double { subtotal * AppConstants.taxRate }
    var total: Double { subtotal + tax }
    
    private init() {}
    
    func add(product: Product, quantity: Int = 1, specialInstructions: String = "") {
        if let index = items.firstIndex(where: { $0.product.id == product.id && $0.specialInstructions == specialInstructions }) {
            items[index].quantity += quantity
        } else {
            let item = CartItem(product: product, quantity: quantity, specialInstructions: specialInstructions)
            items.append(item)
        }
    }
    
    /// Add a custom cake (saved in Firestore) to cart as a single item.
    func addCustomCake(_ customCakeOrder: CustomCakeOrder) {
        guard let docId = customCakeOrder.id else { return }
        let product = Product(
            id: "custom-\(docId)",
            name: "Custom Cake",
            productDescription: customCakeOrder.summary + (customCakeOrder.message.isEmpty ? "" : " · Message: \(customCakeOrder.message)"),
            price: customCakeOrder.price,
            imageURL: customCakeOrder.designImageURL,
            category: ProductCategory.cakes.rawValue,
            isFeatured: false,
            isSoldOut: false
        )
        add(product: product, quantity: 1, specialInstructions: "Custom: \(customCakeOrder.summary)")
    }

    /// Add an AI-designed cake (saved in Firestore) to cart as a single item.
    func addAICakeDesign(_ designOrder: AICakeDesignOrder) {
        guard let docId = designOrder.id else { return }
        let product = Product(
            id: "aicake-\(docId)",
            name: "AI-Designed Cake",
            productDescription: designOrder.summary + " · \(designOrder.designPrompt)",
            price: designOrder.price,
            imageURL: designOrder.generatedImageURL,
            category: ProductCategory.cakes.rawValue,
            isFeatured: false,
            isSoldOut: false
        )
        add(product: product, quantity: 1, specialInstructions: "AI Design: \(designOrder.designPrompt)")
    }

    func updateQuantity(for itemId: String, quantity: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        if quantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = quantity
        }
    }
    
    func remove(itemId: String) {
        items.removeAll { $0.id == itemId }
    }
    
    func clear() {
        items.removeAll()
    }
    
    /// Convert current cart to Order items and clear cart.
    func toOrderItems() -> [OrderItem] {
        items.map { item in
            OrderItem(
                id: item.id,
                productId: item.product.id ?? "",
                name: item.product.name,
                price: item.product.price,
                quantity: item.quantity,
                specialInstructions: item.specialInstructions
            )
        }
    }
}
