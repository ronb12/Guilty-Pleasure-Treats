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

    enum CodingKeys: String, CodingKey {
        case id
        case authorName = "author_name"
        case rating
        case text
        case createdAt = "created_at"
        case productId = "product_id"
    }
}
