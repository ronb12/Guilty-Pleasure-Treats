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
    case treat4Paws = "Treat 4 Paws"
    
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
    /// When non-empty, customer picks a size; each option has its own price. When nil/empty, `price` is the only price.
    var sizeOptions: [ProductSizeOption]?
    
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
        case sizeOptions
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(Int.self, forKey: .id)).map { String($0) }
        name = try c.decode(String.self, forKey: .name)
        productDescription = try c.decodeIfPresent(String.self, forKey: .productDescription) ?? ""
        price = try Self.decodeFlexibleDouble(c, key: .price)
        cost = Self.decodeFlexibleOptionalDouble(c, key: .cost)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        category = try c.decode(String.self, forKey: .category)
        isFeatured = Self.decodeFlexibleBool(c, key: .isFeatured)
        isSoldOut = Self.decodeFlexibleBool(c, key: .isSoldOut)
        isVegetarian = Self.decodeFlexibleBool(c, key: .isVegetarian)
        stockQuantity = Self.decodeFlexibleOptionalInt(c, key: .stockQuantity)
        lowStockThreshold = Self.decodeFlexibleOptionalInt(c, key: .lowStockThreshold)
        createdAt = Product.parseISO8601(try c.decodeIfPresent(String.self, forKey: .createdAt))
        updatedAt = Product.parseISO8601(try c.decodeIfPresent(String.self, forKey: .updatedAt))
        if let opts = try c.decodeIfPresent([ProductSizeOption].self, forKey: .sizeOptions), !opts.isEmpty {
            sizeOptions = opts
        } else {
            sizeOptions = nil
        }
    }
    
    /// JSON number (int/float) or numeric string → `Double` (avoids decode failures from APIs that send `price: 1`).
    private static func decodeFlexibleDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
        if let s = try? c.decode(String.self, forKey: key),
           let v = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return v
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Expected numeric price")
    }

    private static func decodeFlexibleOptionalDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        guard c.contains(key) else { return nil }
        if (try? c.decodeNil(forKey: key)) == true { return nil }
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
        if let s = try? c.decode(String.self, forKey: key) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return nil }
            return Double(t)
        }
        return nil
    }

    private static func decodeFlexibleOptionalInt(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        guard c.contains(key) else { return nil }
        if (try? c.decodeNil(forKey: key)) == true { return nil }
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let d = try? c.decode(Double.self, forKey: key) { return Int(d) }
        if let s = try? c.decode(String.self, forKey: key) {
            return Int(s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    /// Bool, 0/1, or string "true"/"false"/"t"/"f" (avoids bad API payloads marking items sold out).
    private static func decodeFlexibleBool(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Bool {
        if let b = try? c.decode(Bool.self, forKey: key) { return b }
        if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
        if let s = try? c.decode(String.self, forKey: key) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "t", "1", "yes"].contains(t) { return true }
            if ["false", "f", "0", "no", ""].contains(t) { return false }
        }
        return false
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
        updatedAt: Date? = nil,
        sizeOptions: [ProductSizeOption]? = nil
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
        self.sizeOptions = sizeOptions
    }
    
    var isLowStock: Bool {
        guard let q = stockQuantity, let t = lowStockThreshold else { return false }
        return q <= t
    }

    /// When inventory is tracked, sold out means quantity ≤ 0. When not tracked, uses manual `isSoldOut` (no counts).
    var isSoldOutByInventory: Bool {
        if let q = stockQuantity { return q <= 0 }
        return isSoldOut
    }

    /// Admin "Low" badge: low threshold, but not when out of stock (that shows as sold out instead).
    var showsAdminLowStockBadge: Bool {
        if let q = stockQuantity, q <= 0 { return false }
        return isLowStock
    }

    /// Customer menu / catalog: hide when manual sold out, or tracked stock is depleted.
    var isUnavailableOnMenu: Bool {
        if let q = stockQuantity, q <= 0 { return true }
        return isSoldOut
    }

    var categoryEnum: ProductCategory? {
        ProductCategory(rawValue: category)
    }

    /// True when the product has at least one size/price option.
    var hasSizeOptions: Bool {
        !(sizeOptions?.isEmpty ?? true)
    }

    /// Menu list / card: show "From $X" when multiple sizes exist.
    var listingPriceText: String {
        guard let sizes = sizeOptions, let minP = sizes.map(\.price).min() else {
            return price.currencyFormatted
        }
        return "From \(minP.currencyFormatted)"
    }

    /// Unit price for a cart line when a size is selected.
    func unitPrice(forSizeId sizeId: String?) -> Double {
        guard let sizes = sizeOptions, !sizes.isEmpty else { return price }
        guard let sid = sizeId?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty else {
            return sizes.map(\.price).min() ?? price
        }
        if let match = sizes.first(where: { $0.id == sid }) {
            return match.price
        }
        return sizes.map(\.price).min() ?? price
    }

    /// Label for a size id, if known.
    func sizeLabel(forSizeId sizeId: String?) -> String? {
        guard let sid = sizeId?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty else { return nil }
        return sizeOptions?.first(where: { $0.id == sid })?.label
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
        hasher.combine(sizeOptions)
    }
}
