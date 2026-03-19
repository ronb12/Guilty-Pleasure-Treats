//
//  Review.swift
//  Guilty Pleasure Treats
//
//  Customer review from API.
//

import Foundation

struct Review: Identifiable, Codable {
    var id: String
    var authorName: String?
    var rating: Int?
    var text: String?
    var createdAt: Date?
    var productId: String?
    /// When set, review is for this order (DoorDash-style order review).
    var orderId: String?
    var userId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case authorName = "author_name"
        case rating
        case text
        case createdAt = "created_at"
        case productId = "product_id"
        case orderId = "order_id"
        case userId = "user_id"
    }
}
