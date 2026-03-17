//
//  ProductCategoryItem.swift
//  Guilty Pleasure Treats
//
//  Category for products. Owner can add, edit, delete via Admin.
//

import Foundation

struct ProductCategoryItem: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let displayOrder: Int
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayOrder
        case createdAt
        case updatedAt
    }

    init(id: String, name: String, displayOrder: Int, createdAt: String? = nil, updatedAt: String? = nil) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        displayOrder = try c.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}
