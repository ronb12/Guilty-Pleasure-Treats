//
//  Promotion.swift
//  Guilty Pleasure Treats
//
//  Discount codes for admin-created promos (Firestore promotions).
//

import Foundation

enum PromotionDiscountType: String, Codable, CaseIterable, Identifiable {
    case percent = "Percent off"
    case fixed = "Fixed amount off"
    var id: String { rawValue }
}

struct Promotion: Identifiable, Codable {
    var id: String?
    var code: String
    var discountType: String
    var value: Double
    var validFrom: Date?
    var validTo: Date?
    var isActive: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, code, discountType, value, validFrom, validTo, isActive, createdAt
    }

    init(
        id: String? = nil,
        code: String,
        discountType: String = PromotionDiscountType.percent.rawValue,
        value: Double,
        validFrom: Date? = nil,
        validTo: Date? = nil,
        isActive: Bool = true,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.code = code
        self.discountType = discountType
        self.value = value
        self.validFrom = validFrom
        self.validTo = validTo
        self.isActive = isActive
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.decodeFlexibleId(from: c)
        code = try c.decode(String.self, forKey: .code)
        discountType = try c.decodeIfPresent(String.self, forKey: .discountType) ?? PromotionDiscountType.percent.rawValue
        value = try c.decodeIfPresent(Double.self, forKey: .value) ?? 0
        validFrom = try c.decodeIfPresent(Date.self, forKey: .validFrom)
        validTo = try c.decodeIfPresent(Date.self, forKey: .validTo)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(code, forKey: .code)
        try c.encode(discountType, forKey: .discountType)
        try c.encode(value, forKey: .value)
        try c.encodeIfPresent(validFrom, forKey: .validFrom)
        try c.encodeIfPresent(validTo, forKey: .validTo)
        try c.encode(isActive, forKey: .isActive)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    private static func decodeFlexibleId(from c: KeyedDecodingContainer<CodingKeys>) -> String? {
        if let s = try? c.decode(String.self, forKey: .id) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let i = try? c.decode(Int.self, forKey: .id) { return String(i) }
        if let i = try? c.decode(Int64.self, forKey: .id) { return String(i) }
        return nil
    }

    var discountTypeEnum: PromotionDiscountType? { PromotionDiscountType(rawValue: discountType) }

    /// Stable row id for lists (API id when present, else code).
    var listingId: String {
        if let id, !id.isEmpty { return id }
        return code
    }

    /// Active flag plus optional validity window — used for shop home / marketing.
    func isValidForCustomerDisplay(at date: Date = .now) -> Bool {
        guard isActive else { return false }
        if let from = validFrom, date < from { return false }
        if let to = validTo, date > to { return false }
        return true
    }

    /// Short line for home / checkout hints (no PII).
    var customerFacingOfferLine: String {
        let codeUpper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch discountTypeEnum {
        case .percent:
            let pct = value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
            return "\(pct)% off — use code \(codeUpper) at checkout"
        case .fixed:
            let amt = value.currencyFormatted
            return "\(amt) off — use code \(codeUpper) at checkout"
        case .none:
            return "Use code \(codeUpper) at checkout"
        }
    }

    /// Short date note for the home banner (optional).
    var homeValidityCaption: String? {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        switch (validFrom, validTo) {
        case let (from?, to?):
            return "\(df.string(from: from)) – \(df.string(from: to))"
        case let (_, to?):
            return "Ends \(df.string(from: to))"
        case let (from?, _):
            return "Starts \(df.string(from: from))"
        default:
            return nil
        }
    }
}
