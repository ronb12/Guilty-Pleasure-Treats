//
//  Product.swift
//  Guilty Pleasure Treats
//
//  Data model for bakery products.
//

import Foundation

/// Category of baked goods in the menu.
enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case cupcakes = "Cupcakes"
    case cookies = "Cookies"
    case cakes = "Cakes"
    case brownies = "Brownies"
    case seasonalTreats = "Seasonal Treats"
    case treat4Paws = "Treat 4 paws"
    
    var id: String { rawValue }
}

/// Represents a bakery product (cupcake, cookie, cake, etc.).
struct Product: Identifiable, Codable, Equatable, Hashable {
    var id: String?
    var name: String
    var productDescription: String
    var price: Double
    /// Optional cost per unit (for margin/profit view in admin). Not shown to customers.
    var cost: Double?
    var imageURL: String?
    var category: String
    var isFeatured: Bool
    var isSoldOut: Bool
    /// True when the dessert is vegetarian (no gelatin, etc.).
    var isVegetarian: Bool
    /// Optional stock quantity; nil = no inventory tracking.
    var stockQuantity: Int?
    /// When stock ≤ this value, show low-stock alert in admin.
    var lowStockThreshold: Int?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case productDescription = "description"
        case price
        case cost
        case imageURL
        case category
        case isFeatured
        case isSoldOut
        case isVegetarian
        case stockQuantity
        case lowStockThreshold
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(Int.self, forKey: .id)).map { String($0) }
        name = try c.decode(String.self, forKey: .name)
        productDescription = try c.decodeIfPresent(String.self, forKey: .productDescription) ?? ""
        price = try c.decode(Double.self, forKey: .price)
        cost = try c.decodeIfPresent(Double.self, forKey: .cost)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        category = try c.decode(String.self, forKey: .category)
        isFeatured = try c.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        isSoldOut = try c.decodeIfPresent(Bool.self, forKey: .isSoldOut) ?? false
        isVegetarian = try c.decodeIfPresent(Bool.self, forKey: .isVegetarian) ?? false
        stockQuantity = try c.decodeIfPresent(Int.self, forKey: .stockQuantity)
        lowStockThreshold = try c.decodeIfPresent(Int.self, forKey: .lowStockThreshold)
        createdAt = Product.parseISO8601(try c.decodeIfPresent(String.self, forKey: .createdAt))
        updatedAt = Product.parseISO8601(try c.decodeIfPresent(String.self, forKey: .updatedAt))
    }
    
    private static func parseISO8601(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        withFractional.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = withFractional.date(from: s) { return d }
        let without = ISO8601DateFormatter()
        without.formatOptions = [.withInternetDateTime]
        without.timeZone = TimeZone(secondsFromGMT: 0)
        return without.date(from: s)
    }
    
    init(
        id: String? = nil,
        name: String,
        productDescription: String,
        price: Double,
        cost: Double? = nil,
        imageURL: String? = nil,
        category: String,
        isFeatured: Bool = false,
        isSoldOut: Bool = false,
        isVegetarian: Bool = false,
        stockQuantity: Int? = nil,
        lowStockThreshold: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.productDescription = productDescription
        self.price = price
        self.cost = cost
        self.imageURL = imageURL
        self.category = category
        self.isFeatured = isFeatured
        self.isSoldOut = isSoldOut
        self.isVegetarian = isVegetarian
        self.stockQuantity = stockQuantity
        self.lowStockThreshold = lowStockThreshold
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isLowStock: Bool {
        guard let q = stockQuantity, let t = lowStockThreshold else { return false }
        return q <= t
    }
    
    var categoryEnum: ProductCategory? {
        ProductCategory(rawValue: category)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(productDescription)
        hasher.combine(price)
        hasher.combine(cost)
        hasher.combine(imageURL)
        hasher.combine(category)
        hasher.combine(isFeatured)
        hasher.combine(isSoldOut)
        hasher.combine(isVegetarian)
        hasher.combine(stockQuantity)
        hasher.combine(lowStockThreshold)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
    }
}
