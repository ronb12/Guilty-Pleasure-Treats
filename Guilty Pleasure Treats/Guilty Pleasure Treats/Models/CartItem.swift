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
    
    init(id: String = UUID().uuidString, product: Product, quantity: Int = 1, specialInstructions: String = "") {
        self.id = id
        self.product = product
        self.quantity = quantity
        self.specialInstructions = specialInstructions
    }
    
    var subtotal: Double {
        product.price * Double(quantity)
    }
}
