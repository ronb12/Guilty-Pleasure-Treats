//
//  AdminOfferTemplates.swift
//  Guilty Pleasure Treats
//
//  Pre-filled promo and loyalty reward patterns for the admin UI (not stored server-side).
//

import Foundation

// MARK: - Promo codes (10)

struct PromoQuickTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let suggestedCode: String
    let discountType: String
    let value: String
    let minSubtotal: String
    let minQty: String
    let firstOrderOnly: Bool

    static let all: [PromoQuickTemplate] = [
        PromoQuickTemplate(
            id: "welcome_first",
            title: "Welcome — first order 15%",
            subtitle: "15% off cart · first completed order · sign-in required",
            suggestedCode: "WELCOME15",
            discountType: PromotionDiscountType.percent.rawValue,
            value: "15",
            minSubtotal: "",
            minQty: "",
            firstOrderOnly: true
        ),
        PromoQuickTemplate(
            id: "treats10",
            title: "Seasonal 10% off",
            subtitle: "10% off entire cart · any customer",
            suggestedCode: "TREATS10",
            discountType: PromotionDiscountType.percent.rawValue,
            value: "10",
            minSubtotal: "",
            minQty: "",
            firstOrderOnly: false
        ),
        PromoQuickTemplate(
            id: "save5",
            title: "Five dollars off",
            subtitle: "Fixed $5 off subtotal · stacks with your rules as usual",
            suggestedCode: "SAVE5",
            discountType: PromotionDiscountType.fixed.rawValue,
            value: "5",
            minSubtotal: "",
            minQty: "",
            firstOrderOnly: false
        ),
        PromoQuickTemplate(
            id: "vip50",
            title: "VIP — 20% at $50+",
            subtitle: "20% off when cart subtotal reaches $50",
            suggestedCode: "VIP20",
            discountType: PromotionDiscountType.percent.rawValue,
            value: "20",
            minSubtotal: "50",
            minQty: "",
            firstOrderOnly: false
        ),
        PromoQuickTemplate(
            id: "free_item",
            title: "Free menu item",
            subtitle: "100% off one catalog item — tap Applies to and choose that product",
            suggestedCode: "FREETREAT",
            discountType: PromotionDiscountType.percent.rawValue,
            value: "100",
            minSubtotal: "",
            minQty: "1",
            firstOrderOnly: false
        ),
        PromoQuickTemplate(
            id: "student",
            title: "Student / community 10%",
            subtitle: "10% off cart — rename the code to match your campaign",
            suggestedCode: "STUDENT10",
            discountType: PromotionDiscountType.percent.rawValue,
            value: "10",
            minSubtotal: "",
            minQty: "",
            firstOrderOnly: false
        ),
        PromoQuickTemplate(
            id: "flash_sale",
            title: "Flash sale 25%",
            subtitle: "High-impact limited-time percent off whole cart",
            suggestedCode: "FLASH25",
            discountType: PromotionDiscountType.percent.rawValue,
            value: "25",
            minSubtotal: "",
            minQty: "",
            firstOrderOnly: false
        ),
        PromoQuickTemplate(
            id: "order_tracking",
            title: "Thank-you code (no discount)",
            subtitle: "Code saved on orders for tracking — no automatic dollar off",
            suggestedCode: "THANKYOU",
            discountType: PromotionDiscountType.none.rawValue,
            value: "",
            minSubtotal: "",
            minQty: "",
            firstOrderOnly: false
        ),
        PromoQuickTemplate(
            id: "multi_item",
            title: "Multi-item 10%",
            subtitle: "10% off when cart has at least 2 items total",
            suggestedCode: "MORE10",
            discountType: PromotionDiscountType.percent.rawValue,
            value: "10",
            minSubtotal: "",
            minQty: "2",
            firstOrderOnly: false
        ),
        PromoQuickTemplate(
            id: "min_spend_25",
            title: "Spring 15% at $25+",
            subtitle: "15% off after $25 subtotal — good for small upsell",
            suggestedCode: "SPRING15",
            discountType: PromotionDiscountType.percent.rawValue,
            value: "15",
            minSubtotal: "25",
            minQty: "",
            firstOrderOnly: false
        ),
    ]

    /// Shown under the template picker so admins see what the preset applies.
    var adminDetailDescription: String {
        var lines: [String] = [subtitle, ""]
        lines.append("Suggested code: \(suggestedCode)")
        let typeLabel = discountType.trimmingCharacters(in: .whitespacesAndNewlines)
        if typeLabel == PromotionDiscountType.none.rawValue {
            lines.append("Type: No automatic discount (tracking / manual perks)")
        } else if typeLabel == PromotionDiscountType.percent.rawValue {
            lines.append("Type: Percent off — \(value)%")
        } else if typeLabel == PromotionDiscountType.fixed.rawValue {
            lines.append("Type: Fixed amount — $\(value) off subtotal")
        } else {
            lines.append("Type: \(typeLabel) — value: \(value)")
        }
        let minSub = minSubtotal.trimmingCharacters(in: .whitespacesAndNewlines)
        if !minSub.isEmpty {
            lines.append("Minimum cart: $\(minSub)")
        }
        let minQ = minTotalQuantityTextSanitized
        if !minQ.isEmpty {
            lines.append("Minimum total items in cart: \(minQ)")
        }
        lines.append(firstOrderOnly ? "First order only: Yes (customer must be signed in)" : "First order only: No")
        lines.append("Product scope: Use “Applies to” below — whole cart unless you pick one item (required for free-item promos).")
        return lines.joined(separator: "\n")
    }

    private var minTotalQuantityTextSanitized: String {
        minQty.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Loyalty rewards (10)

struct LoyaltyRewardQuickTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let suggestedName: String
    let pointsRequired: Int
    let sortOrder: Int

    static let all: [LoyaltyRewardQuickTemplate] = [
        LoyaltyRewardQuickTemplate(
            id: "cookie",
            title: "Cookie reward",
            subtitle: "Low points — good first milestone",
            suggestedName: "Cookie on us",
            pointsRequired: 10,
            sortOrder: 0
        ),
        LoyaltyRewardQuickTemplate(
            id: "cupcake",
            title: "Cupcake reward",
            subtitle: "Mid tier treat",
            suggestedName: "Free cupcake",
            pointsRequired: 50,
            sortOrder: 1
        ),
        LoyaltyRewardQuickTemplate(
            id: "birthday",
            title: "Birthday treat",
            subtitle: "Special occasion redemption",
            suggestedName: "Birthday treat",
            pointsRequired: 100,
            sortOrder: 2
        ),
        LoyaltyRewardQuickTemplate(
            id: "celebration",
            title: "Celebration dessert",
            subtitle: "Higher points for a premium item",
            suggestedName: "Celebration dessert",
            pointsRequired: 200,
            sortOrder: 3
        ),
        LoyaltyRewardQuickTemplate(
            id: "sweet25",
            title: "Sweet reward",
            subtitle: "Small thank-you redemption",
            suggestedName: "Sweet reward",
            pointsRequired: 25,
            sortOrder: 4
        ),
        LoyaltyRewardQuickTemplate(
            id: "brownie",
            title: "Brownie bite",
            subtitle: "Entry-level chocolate reward",
            suggestedName: "Brownie bite",
            pointsRequired: 15,
            sortOrder: 5
        ),
        LoyaltyRewardQuickTemplate(
            id: "seasonal_box",
            title: "Seasonal box",
            subtitle: "Mid-high tier for holiday assortments",
            suggestedName: "Seasonal treat box",
            pointsRequired: 75,
            sortOrder: 6
        ),
        LoyaltyRewardQuickTemplate(
            id: "mini_cake",
            title: "Mini cake",
            subtitle: "Personal-size cake redemption",
            suggestedName: "Mini cake",
            pointsRequired: 150,
            sortOrder: 7
        ),
        LoyaltyRewardQuickTemplate(
            id: "party_pack",
            title: "Party pack",
            subtitle: "Large bundle for events",
            suggestedName: "Party dessert pack",
            pointsRequired: 350,
            sortOrder: 8
        ),
        LoyaltyRewardQuickTemplate(
            id: "vip_tier",
            title: "VIP dessert",
            subtitle: "Top tier — signature or custom item",
            suggestedName: "VIP dessert reward",
            pointsRequired: 500,
            sortOrder: 9
        ),
    ]

    /// Shown under the template picker so admins see what the preset applies.
    var adminDetailDescription: String {
        """
        \(subtitle)

        • Display name: \(suggestedName)
        • Points required: \(pointsRequired)
        • List order: \(sortOrder) (lower appears first in the app)

        Choose the free catalog product below — the customer receives that menu item at $0 when they redeem.
        """
    }
}
