//
//  Promotion.swift
//  Guilty Pleasure Treats
//
//  Discount codes for admin-created promos (Firestore promotions).
//

import Foundation

enum PromotionDiscountType: String, Codable, CaseIterable, Identifiable {
    /// Subtotal is reduced by `value` percent (e.g. 10 = 10% off).
    case percent = "Percent off"
    /// Subtotal is reduced by `value` dollars (capped at subtotal). Code is validated like any other promo type.
    case fixed = "Fixed amount off"
    /// No dollar amount off subtotal; code is still validated and saved on the order (tracking, eligibility, or perks you apply manually).
    case none = "None"
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
    /// Minimum cart subtotal (dollars) before discount applies. Nil = no minimum.
    var minSubtotal: Double?
    /// Minimum sum of line item quantities. Nil = no minimum.
    var minTotalQuantity: Int?
    /// When true, customer must be signed in with zero prior completed orders.
    var firstOrderOnly: Bool
    /// When set, the promo applies only to cart lines for this catalog product id (server-enforced).
    var productId: String?

    enum CodingKeys: String, CodingKey {
        case id, code, discountType, value, validFrom, validTo, isActive, createdAt
        case minSubtotal, minTotalQuantity, firstOrderOnly, productId
    }

    init(
        id: String? = nil,
        code: String,
        discountType: String = PromotionDiscountType.percent.rawValue,
        value: Double,
        validFrom: Date? = nil,
        validTo: Date? = nil,
        isActive: Bool = true,
        createdAt: Date? = nil,
        minSubtotal: Double? = nil,
        minTotalQuantity: Int? = nil,
        firstOrderOnly: Bool = false,
        productId: String? = nil
    ) {
        self.id = id
        self.code = code
        self.discountType = discountType
        self.value = value
        self.validFrom = validFrom
        self.validTo = validTo
        self.isActive = isActive
        self.createdAt = createdAt
        self.minSubtotal = minSubtotal
        self.minTotalQuantity = minTotalQuantity
        self.firstOrderOnly = firstOrderOnly
        self.productId = productId
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
        minSubtotal = try c.decodeIfPresent(Double.self, forKey: .minSubtotal)
        minTotalQuantity = try c.decodeIfPresent(Int.self, forKey: .minTotalQuantity)
        firstOrderOnly = try c.decodeIfPresent(Bool.self, forKey: .firstOrderOnly) ?? false
        productId = try c.decodeIfPresent(String.self, forKey: .productId)
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
        try c.encodeIfPresent(minSubtotal, forKey: .minSubtotal)
        try c.encodeIfPresent(minTotalQuantity, forKey: .minTotalQuantity)
        try c.encode(firstOrderOnly, forKey: .firstOrderOnly)
        try c.encodeIfPresent(productId, forKey: .productId)
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
        case .some(.percent):
            let pct = value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
            return "\(pct)% off — use code \(codeUpper) at checkout"
        case .some(.fixed):
            let amt = value.currencyFormatted
            return "\(amt) off — use code \(codeUpper) at checkout"
        case .some(.none), nil:
            return "Use code \(codeUpper) at checkout"
        }
    }

    /// Extra line for banners (requirements only).
    var rewardRulesCaption: String? {
        var parts: [String] = []
        if let m = minSubtotal, m > 0 {
            parts.append("Min \(m.currencyFormatted) cart")
        }
        if let q = minTotalQuantity, q > 0 {
            parts.append(productId?.isEmpty == false ? "Min \(q) of that product" : "Min \(q) items")
        }
        if firstOrderOnly {
            parts.append("First order only")
        }
        if productId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append("Specific product")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    /// Subtotal and quantity used for rules/discount when `productId` is set.
    func promoEligibleSubtotal(orderItems: [OrderItem]) -> Double {
        guard let t = productId?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return orderItems.reduce(0) { $0 + $1.subtotal }
        }
        let target = t.lowercased()
        return orderItems
            .filter { $0.productId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target }
            .reduce(0) { $0 + $1.subtotal }
    }

    func promoEligibleItemQuantity(orderItems: [OrderItem]) -> Int {
        guard let t = productId?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return orderItems.reduce(0) { $0 + $1.quantity }
        }
        let target = t.lowercased()
        return orderItems
            .filter { $0.productId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target }
            .reduce(0) { $0 + $1.quantity }
    }

    /// Matches server `promotionEligibilityFailure` copy for consistent UX.
    func eligibilityFailureMessage(
        orderItems: [OrderItem],
        signedInUser: Bool,
        priorCompletedOrderCount: Int?
    ) -> String? {
        let scoped = productId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let subForRules = scoped ? promoEligibleSubtotal(orderItems: orderItems) : orderItems.reduce(0) { $0 + $1.subtotal }
        let qtyForRules = scoped ? promoEligibleItemQuantity(orderItems: orderItems) : orderItems.reduce(0) { $0 + $1.quantity }

        if scoped, subForRules + 1e-9 <= 0 {
            return "Add the promoted product to your cart to use this code."
        }
        guard subForRules.isFinite, subForRules >= 0 else {
            return "Invalid cart subtotal."
        }
        if let minS = minSubtotal, minS > 0, subForRules + 1e-9 < minS {
            if scoped {
                return String(format: "This promo needs at least $%.2f of that product before discount (you have $%.2f).", minS, subForRules)
            }
            return String(format: "This promo needs a minimum cart of $%.2f before discount (you have $%.2f).", minS, subForRules)
        }
        if let minQ = minTotalQuantity, minQ > 0, qtyForRules < minQ {
            if scoped {
                return "This promo needs at least \(minQ) of that product in your cart (you have \(qtyForRules))."
            }
            return "This promo needs at least \(minQ) items in your cart (you have \(qtyForRules))."
        }
        if firstOrderOnly {
            if !signedInUser {
                return "Sign in with your account to use this first-order promo."
            }
            guard let prior = priorCompletedOrderCount else {
                return "Could not verify first-order eligibility. Please try again."
            }
            if prior > 0 {
                return "This promo is only for your first order."
            }
        }
        return nil
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
