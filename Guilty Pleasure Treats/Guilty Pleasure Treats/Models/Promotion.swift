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
    
    var discountTypeEnum: PromotionDiscountType? { PromotionDiscountType(rawValue: discountType) }
}
