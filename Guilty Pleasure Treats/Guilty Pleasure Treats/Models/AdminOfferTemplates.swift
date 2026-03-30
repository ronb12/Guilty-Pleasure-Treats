//
//  AdminOfferTemplates.swift
//  Guilty Pleasure Treats
//
//  Pre-filled promo and loyalty reward patterns for the admin UI (not stored server-side).
//

import Foundation

// MARK: - Promo codes (5)

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
    ]
}

// MARK: - Loyalty rewards (5)

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
    ]
}
