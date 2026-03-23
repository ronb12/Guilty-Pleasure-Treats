//
//  BusinessSettings.swift
//  Guilty Pleasure Treats
//
//  Store-wide settings editable by admin (Firestore settings/business).
//

import Foundation

struct BusinessSettings: Codable {
    var storeHours: String?
    var deliveryRadiusMiles: Double?
    var taxRate: Double
    /// Minimum hours from now before a customer can select pickup/delivery/ship date. Shown in checkout.
    var minimumOrderLeadTimeHours: Int?
    var contactEmail: String?
    var contactPhone: String?
    var storeName: String?
    /// Cash App $Cashtag (e.g. $GuiltyPleasureTreats) for QR / in-app payment option.
    var cashAppTag: String?
    /// Venmo username for optional QR / link payment.
    var venmoUsername: String?
    /// Delivery fee in dollars (e.g. 5.00). Applied at checkout when fulfillment is Delivery.
    var deliveryFee: Double?
    /// Shipping fee in dollars (e.g. 8.00). Applied at checkout when fulfillment is Shipping.
    var shippingFee: Double?
    /// ISO8601 timestamp when an admin last saved business settings (from API).
    var settingsLastUpdatedAt: String?
    /// User id (from auth) who last saved settings; informational only.
    var settingsLastUpdatedByUserId: String?
    /// Display name (or email fallback) of the user who last saved settings.
    var settingsLastUpdatedByName: String?
    /// Stripe publishable key (`pk_live_…` / `pk_test_…`) for in-app Payment Sheet; from server when admin saves it.
    var stripePublishableKey: String?
    /// Server can create PaymentIntents (secret key in env or DB).
    var stripeCheckoutEnabled: Bool
    /// A Stripe secret key is configured (value never returned).
    var stripeSecretKeyConfigured: Bool

    init(
        storeHours: String? = nil,
        deliveryRadiusMiles: Double? = nil,
        taxRate: Double = 0.08,
        minimumOrderLeadTimeHours: Int? = nil,
        contactEmail: String? = nil,
        contactPhone: String? = nil,
        storeName: String? = nil,
        cashAppTag: String? = nil,
        venmoUsername: String? = nil,
        deliveryFee: Double? = nil,
        shippingFee: Double? = nil,
        settingsLastUpdatedAt: String? = nil,
        settingsLastUpdatedByUserId: String? = nil,
        settingsLastUpdatedByName: String? = nil,
        stripePublishableKey: String? = nil,
        stripeCheckoutEnabled: Bool = false,
        stripeSecretKeyConfigured: Bool = false
    ) {
        self.storeHours = storeHours
        self.deliveryRadiusMiles = deliveryRadiusMiles
        self.taxRate = taxRate
        self.minimumOrderLeadTimeHours = minimumOrderLeadTimeHours
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.storeName = storeName
        self.cashAppTag = cashAppTag
        self.venmoUsername = venmoUsername
        self.deliveryFee = deliveryFee
        self.shippingFee = shippingFee
        self.settingsLastUpdatedAt = settingsLastUpdatedAt
        self.settingsLastUpdatedByUserId = settingsLastUpdatedByUserId
        self.settingsLastUpdatedByName = settingsLastUpdatedByName
        self.stripePublishableKey = stripePublishableKey
        self.stripeCheckoutEnabled = stripeCheckoutEnabled
        self.stripeSecretKeyConfigured = stripeSecretKeyConfigured
    }
}
