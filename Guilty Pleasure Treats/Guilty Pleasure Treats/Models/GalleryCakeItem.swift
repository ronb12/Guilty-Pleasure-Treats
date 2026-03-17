//
//  GalleryCakeItem.swift
//  Guilty Pleasure Treats
//
//  Owner showcase item: photo + title/description/category/price. Cakes, cookies, cupcakes, etc. Customers browse and can order.
//

import Foundation

struct GalleryCakeItem: Identifiable, Codable {
    var id: String
    var imageUrl: String?
    var title: String
    var description: String?
    var category: String?
    var price: Double?
    var displayOrder: Int
    var createdAt: String?
    var updatedAt: String?
}
