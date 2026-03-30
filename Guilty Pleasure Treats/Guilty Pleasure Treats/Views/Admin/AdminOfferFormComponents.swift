//
//  AdminOfferFormComponents.swift
//  Dropdown-first helpers for admin promo & loyalty reward forms.
//

import SwiftUI

enum AdminOfferForm {
    /// Tag for "type a custom value" rows in pickers.
    static let customTag = "__custom__"
    static let minNoneTag = "__min_none__"

    static let percentValues = ["5", "10", "15", "20", "25", "50", "100"]
    static let fixedDollarValues = ["1", "2", "3", "5", "10", "15", "20", "25"]
    static let minCartDollars = ["10", "15", "25", "50", "75", "100"]
    static let minItemCounts = ["1", "2", "3", "5", "10"]
    static let loyaltyPoints = ["10", "15", "25", "50", "75", "100", "150", "200", "350", "500"]
    static let sortOrders = (0 ... 20).map { String($0) }

    /// Picker tag for the discount value row given current type and text.
    static func promoValueTag(discountType: String, valueText: String) -> String {
        let t = valueText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        if discountType == PromotionDiscountType.none.rawValue { return customTag }
        if t.isEmpty { return customTag }
        if discountType == PromotionDiscountType.percent.rawValue {
            if let d = Double(t) {
                let whole = String(format: "%.0f", d)
                return percentValues.contains(whole) ? whole : customTag
            }
            return percentValues.contains(t) ? t : customTag
        }
        if discountType == PromotionDiscountType.fixed.rawValue {
            if let d = Double(t) {
                let whole = String(format: "%.0f", d)
                return fixedDollarValues.contains(whole) ? whole : customTag
            }
            return customTag
        }
        return customTag
    }

    static func minCartTag(minSubtotalText: String) -> String {
        let t = minSubtotalText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        if t.isEmpty { return minNoneTag }
        if let d = Double(t) {
            let s = String(format: "%.0f", d)
            return minCartDollars.contains(s) ? s : customTag
        }
        return minCartDollars.contains(t) ? t : customTag
    }

    static func minQtyTag(minTotalQuantityText: String) -> String {
        let t = minTotalQuantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return minNoneTag }
        if let i = Int(t), minItemCounts.contains(String(i)) {
            return String(i)
        }
        if minItemCounts.contains(t) { return t }
        return customTag
    }

    static func loyaltyPointsTag(pointsText: String) -> String {
        let t = pointsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if loyaltyPoints.contains(t) { return t }
        if let i = Int(t), loyaltyPoints.contains(String(i)) { return String(i) }
        return customTag
    }

    static func sortOrderTag(sortOrderText: String) -> String {
        let t = sortOrderText.trimmingCharacters(in: .whitespacesAndNewlines)
        if sortOrders.contains(t) { return t }
        if let i = Int(t), sortOrders.contains(String(i)) { return String(i) }
        return customTag
    }
}
