//
//  Product.swift
//  Guilty Pleasure Treats
//
//  Data model for bakery products.
//

import Foundation
import FirebaseFirestore

/// Category of baked goods in the menu.
enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case cupcakes = "Cupcakes"
    case cookies = "Cookies"
    case cakes = "Cakes"
    case brownies = "Brownies"
    case seasonalTreats = "Seasonal Treats"
    
    var id: String { rawValue }
}

/// Represents a bakery product (cupcake, cookie, cake, etc.).
struct Product: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var productDescription: String
    var price: Double
    var imageURL: String?
    var category: String
    var isFeatured: Bool
    var isSoldOut: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case productDescription = "description"
        case price
        case imageURL
        case category
        case isFeatured
        case isSoldOut
        case createdAt
        case updatedAt
    }
    
    init(
        id: String? = nil,
        name: String,
        productDescription: String,
        price: Double,
        imageURL: String? = nil,
        category: String,
        isFeatured: Bool = false,
        isSoldOut: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.productDescription = productDescription
        self.price = price
        self.imageURL = imageURL
        self.category = category
        self.isFeatured = isFeatured
        self.isSoldOut = isSoldOut
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var categoryEnum: ProductCategory? {
        ProductCategory(rawValue: category)
    }
}
