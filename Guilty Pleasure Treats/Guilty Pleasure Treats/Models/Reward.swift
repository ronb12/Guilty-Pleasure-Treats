//
//  Reward.swift
//  Guilty Pleasure Treats
//
//  Loyalty reward options: points required and the free product to add to cart.
//

import Foundation

/// A reward the user can redeem with points. Redeeming adds a free product to the cart.
struct RewardOption: Identifiable {
    var id: String { "\(pointsRequired)-\(productToAdd.name)" }
    let name: String
    let pointsRequired: Int
    /// Product to add to cart when redeemed (price 0).
    let productToAdd: Product
}

/// Static list of available rewards and helper to build the free-product for cart.
enum Rewards {
    /// 50 points = free cookie
    static let freeCookie = RewardOption(
        name: "Free Cookie",
        pointsRequired: 50,
        productToAdd: Product(
            id: "reward-free-cookie",
            name: "Free Cookie (Reward)",
            productDescription: "Redeemed with 50 loyalty points.",
            price: 0,
            imageURL: nil,
            category: ProductCategory.cookies.rawValue,
            isFeatured: false,
            isSoldOut: false
        )
    )
    /// 100 points = free cupcake
    static let freeCupcake = RewardOption(
        name: "Free Cupcake",
        pointsRequired: 100,
        productToAdd: Product(
            id: "reward-free-cupcake",
            name: "Free Cupcake (Reward)",
            productDescription: "Redeemed with 100 loyalty points.",
            price: 0,
            imageURL: nil,
            category: ProductCategory.cupcakes.rawValue,
            isFeatured: false,
            isSoldOut: false
        )
    )
    
    static var all: [RewardOption] { [freeCookie, freeCupcake] }
}
