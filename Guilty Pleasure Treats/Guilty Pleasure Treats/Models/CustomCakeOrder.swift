//
//  CustomCakeOrder.swift
//  Guilty Pleasure Treats
//
//  Model for user-built custom cake; saved to Firestore and added to cart.
//

import Foundation

enum CakeSize: String, Codable, CaseIterable, Identifiable {
    case six = "6 inch"
    case eight = "8 inch"
    case ten = "10 inch"
    var id: String { rawValue }
    var price: Double {
        switch self {
        case .six: return 24
        case .eight: return 32
        case .ten: return 42
        }
    }
}

enum CakeFlavor: String, Codable, CaseIterable, Identifiable {
    case chocolate = "Chocolate"
    case vanilla = "Vanilla"
    case redVelvet = "Red Velvet"
    case strawberry = "Strawberry"
    var id: String { rawValue }
}

enum FrostingType: String, Codable, CaseIterable, Identifiable {
    case vanillaButtercream = "Vanilla Buttercream"
    case chocolate = "Chocolate"
    case creamCheese = "Cream Cheese"
    var id: String { rawValue }
}

struct CustomCakeOrder: Identifiable, Codable {
    var id: String?
    var userId: String?
    var size: String
    var flavor: String
    var frosting: String
    var message: String
    var designImageURL: String?
    var price: Double
    var orderId: String?
    var createdAt: Date?
    
    var sizeEnum: CakeSize? { CakeSize(rawValue: size) }
    var flavorEnum: CakeFlavor? { CakeFlavor(rawValue: flavor) }
    var frostingEnum: FrostingType? { FrostingType(rawValue: frosting) }
    
    /// Short summary for cart/order display.
    var summary: String {
        [size, flavor, frosting]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
