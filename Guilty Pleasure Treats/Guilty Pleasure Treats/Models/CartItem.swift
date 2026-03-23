//
//  CartItem.swift
//  Guilty Pleasure Treats
//
//  Represents an item in the shopping cart with quantity and optional instructions.
//

import Foundation

struct CartItem: Identifiable, Equatable {
    let id: String
    let product: Product
    var quantity: Int
    var specialInstructions: String
    /// When set, `product.unitPrice(forSizeId:)` applies; `selectedSizeLabel` is shown in cart/order.
    var selectedSizeId: String?
    var selectedSizeLabel: String?

    init(
        id: String = UUID().uuidString,
        product: Product,
        quantity: Int = 1,
        specialInstructions: String = "",
        selectedSizeId: String? = nil,
        selectedSizeLabel: String? = nil
    ) {
        self.id = id
        self.product = product
        self.quantity = quantity
        self.specialInstructions = specialInstructions
        self.selectedSizeId = selectedSizeId
        self.selectedSizeLabel = selectedSizeLabel
    }

    var unitPrice: Double {
        product.unitPrice(forSizeId: selectedSizeId)
    }

    var subtotal: Double {
        unitPrice * Double(quantity)
    }
}
