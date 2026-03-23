//
//  ProductSizeOption.swift
//  Guilty Pleasure Treats
//
//  Optional per-product sizes (e.g. Small / Large) with individual prices.
//

import Foundation

struct ProductSizeOption: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var label: String
    var price: Double

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case price
    }

    init(id: String, label: String, price: Double) {
        self.id = id
        self.label = label
        self.price = price
    }

    /// Create from admin or local UI; `id` is derived from the label (stable slug).
    init(label: String, price: Double) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = trimmed
        self.price = price
        self.id = Self.slugFromLabel(trimmed)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        price = try Self.decodeFlexiblePrice(c)
        let rawId = try c.decodeIfPresent(String.self, forKey: .id)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        id = rawId.isEmpty ? Self.slugFromLabel(label) : rawId
    }

    private static func decodeFlexiblePrice(_ c: KeyedDecodingContainer<CodingKeys>) throws -> Double {
        if let d = try? c.decode(Double.self, forKey: .price) { return d }
        if let i = try? c.decode(Int.self, forKey: .price) { return Double(i) }
        if let s = try? c.decode(String.self, forKey: .price),
           let v = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return v
        }
        throw DecodingError.dataCorruptedError(forKey: .price, in: c, debugDescription: "Expected numeric price")
    }

    /// Stable id from label when API omits `id`.
    static func slugFromLabel(_ label: String) -> String {
        let t = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let folded = t.folding(options: .diacriticInsensitive, locale: .current)
        let slug = folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString.prefix(8).lowercased() + "-size" : String(slug)
    }
}
