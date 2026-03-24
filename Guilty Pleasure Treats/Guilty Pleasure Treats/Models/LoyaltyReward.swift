//
//  LoyaltyReward.swift
//  Guilty Pleasure Treats
//
//  Server-driven loyalty rewards (points → free product). Admin edits via API.
//

import Foundation

/// One row from GET /api/loyalty-rewards.
struct LoyaltyRewardItem: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var pointsRequired: Int
    var sortOrder: Int
    var isActive: Bool
    var productId: String?
    var product: Product?

    enum CodingKeys: String, CodingKey {
        case id, name, pointsRequired, sortOrder, isActive, productId, product
    }

    init(id: String, name: String, pointsRequired: Int, sortOrder: Int, isActive: Bool, productId: String?, product: Product?) {
        self.id = id
        self.name = name
        self.pointsRequired = pointsRequired
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.productId = productId
        self.product = product
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Invalid id")
        }
        name = try c.decode(String.self, forKey: .name)
        pointsRequired = try c.decode(Int.self, forKey: .pointsRequired)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        productId = try c.decodeIfPresent(String.self, forKey: .productId)
        product = try c.decodeIfPresent(Product.self, forKey: .product)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(pointsRequired, forKey: .pointsRequired)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(isActive, forKey: .isActive)
        try c.encodeIfPresent(productId, forKey: .productId)
        try c.encodeIfPresent(product, forKey: .product)
    }
}
