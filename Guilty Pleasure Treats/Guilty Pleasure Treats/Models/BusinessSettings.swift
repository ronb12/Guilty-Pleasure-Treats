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
    
    init(
        storeHours: String? = nil,
        deliveryRadiusMiles: Double? = nil,
        taxRate: Double = 0.08,
        minimumOrderLeadTimeHours: Int? = nil,
        contactEmail: String? = nil,
        contactPhone: String? = nil,
        storeName: String? = nil,
        cashAppTag: String? = nil,
        venmoUsername: String? = nil
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
    }
}
