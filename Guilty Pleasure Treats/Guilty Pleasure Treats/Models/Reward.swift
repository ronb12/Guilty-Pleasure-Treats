//
//  Reward.swift
//  Guilty Pleasure Treats
//
//  Loyalty reward options: points required and the free product to add to cart.
//

import Foundation

/// A reward the user can redeem with points. Redeeming adds a free product to the cart.
struct RewardOption: Identifiable, Equatable {
    var id: String { serverId ?? "local-\(pointsRequired)-\(productToAdd.name)" }
    /// Server UUID when loaded from `/api/loyalty-rewards`.
    let serverId: String?
    let name: String
    let pointsRequired: Int
    /// Price should be 0 for redemption.
    let productToAdd: Product
}
