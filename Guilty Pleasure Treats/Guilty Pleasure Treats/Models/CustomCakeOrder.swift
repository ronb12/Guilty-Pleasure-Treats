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
    case strawberry = "Strawberry"
    case lemon = "Lemon"
    case peanutButter = "Peanut Butter"
    case saltedCaramel = "Salted Caramel"
    case mocha = "Mocha"
    case cookiesAndCream = "Cookies & Cream"
    case coconut = "Coconut"
    case maple = "Maple"
    case vanillaBean = "Vanilla Bean"
    var id: String { rawValue }
}

/// Fallback topping options when API has none.
enum CakeTopping: String, Codable, CaseIterable, Identifiable {
    case freshStrawberries = "Fresh Strawberries"
    case sprinkles = "Sprinkles"
    case chocolateShavings = "Chocolate Shavings"
    case edibleFlowers = "Edible Flowers"
    case freshBerries = "Fresh Berries"
    case coconutFlakes = "Coconut Flakes"
    case crushedOreos = "Crushed Oreos"
    case caramelDrizzle = "Caramel Drizzle"
    case goldDust = "Gold Dust"
    case customMessage = "Custom Message (included)"
    var id: String { rawValue }
    var price: Double {
        switch self {
        case .freshStrawberries, .freshBerries, .edibleFlowers, .goldDust: return 5
        case .sprinkles, .chocolateShavings, .coconutFlakes, .crushedOreos, .caramelDrizzle: return 2
        case .customMessage: return 0
        }
    }
}

struct CustomCakeOrder: Identifiable, Codable {
    var id: String?
    var userId: String?
    var size: String
    var flavor: String
    var frosting: String
    var toppings: [String]?
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
        var parts = [size, flavor, frosting]
        if let tops = toppings, !tops.isEmpty {
            parts.append("+ \(tops.joined(separator: ", "))")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
