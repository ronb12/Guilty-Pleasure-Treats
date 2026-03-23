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
    @Published var tipAmount: Double = 0
    /// Decimal rate (e.g. 0.08). Synced from business settings when cart/checkout load settings; fallback `AppConstants.taxRate`.
    @Published var taxRate: Double = AppConstants.taxRate
    /// Shown on cart/checkout when business settings could not be loaded (tax may use defaults).
    @Published var businessSettingsWarning: String?
    /// `pk_live_…` / `pk_test_…` from server business settings (admin-configured).
    @Published private(set) var stripePublishableKeyFromServer: String?
    /// True when the API reports the backend can create Stripe PaymentIntents.
    @Published private(set) var stripeCheckoutEnabledFromServer: Bool = false

    var isEmpty: Bool { items.isEmpty }
    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var subtotal: Double { items.reduce(0) { $0 + $1.subtotal } }
    var tax: Double { subtotal * taxRate }
    var total: Double { subtotal + tax + tipAmount }

    private init() {}

    func applyBusinessSettingsFromServer(_ settings: BusinessSettings) {
        taxRate = settings.taxRate
        businessSettingsWarning = nil
        stripePublishableKeyFromServer = settings.stripePublishableKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        stripeCheckoutEnabledFromServer = settings.stripeCheckoutEnabled
        #if os(iOS)
        if let k = stripePublishableKeyFromServer, !k.isEmpty {
            StripeService.configure(publishableKey: k)
        } else if let fallback = AppConstants.stripePublishableKey?.trimmingCharacters(in: .whitespacesAndNewlines), !fallback.isEmpty {
            // API may omit pk until Admin saves or STRIPE_PUBLISHABLE_KEY is set on Vercel; keep SDK configured.
            StripeService.configure(publishableKey: fallback)
        }
        #endif
    }

    func markBusinessSettingsLoadFailed() {
        businessSettingsWarning = "Couldn't load the latest store settings. Tax and totals may use defaults until you're online."
    }

    func setTipAmount(_ amount: Double) {
        tipAmount = max(0, amount)
    }
    
    func add(
        product: Product,
        quantity: Int = 1,
        specialInstructions: String = "",
        selectedSizeId: String? = nil,
        selectedSizeLabel: String? = nil
    ) {
        if let index = items.firstIndex(where: {
            $0.product.id == product.id
                && $0.specialInstructions == specialInstructions
                && $0.selectedSizeId == selectedSizeId
        }) {
            items[index].quantity += quantity
        } else {
            let item = CartItem(
                product: product,
                quantity: quantity,
                specialInstructions: specialInstructions,
                selectedSizeId: selectedSizeId,
                selectedSizeLabel: selectedSizeLabel
            )
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
        tipAmount = 0
    }
    
    /// Convert current cart to Order items and clear cart.
    func toOrderItems() -> [OrderItem] {
        items.map { item in
            OrderItem(
                id: item.id,
                productId: item.product.id ?? "",
                name: item.product.name,
                price: item.unitPrice,
                quantity: item.quantity,
                specialInstructions: item.specialInstructions,
                sizeLabel: item.selectedSizeLabel
            )
        }
    }
}
