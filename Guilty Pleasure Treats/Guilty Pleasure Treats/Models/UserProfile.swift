//
//  UserProfile.swift
//  Guilty Pleasure Treats
//
//  User profile and admin flag (Vercel/Neon).
//

import Foundation

struct UserProfile: Codable {
    var uid: String
    var email: String?
    var displayName: String?
    /// Customer phone from account (sign-up / profile); prefill checkout.
    var phone: String?
    var isAdmin: Bool
    /// Loyalty points: 1 point per $1 spent. Stored in Firestore.
    var points: Int
    var createdAt: Date?
    /// Prior orders count from API (for first-order promos). Omitted in older API responses.
    var completedOrderCount: Int
    /// Marketing newsletter / offers by email (server: not in `newsletter_suppressions`).
    var marketingEmailOptIn: Bool
    
    init(uid: String, email: String? = nil, displayName: String? = nil, phone: String? = nil, isAdmin: Bool = false, points: Int = 0, createdAt: Date? = nil, completedOrderCount: Int = 0, marketingEmailOptIn: Bool = true) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.phone = phone
        self.isAdmin = isAdmin
        self.points = points
        self.createdAt = createdAt
        self.completedOrderCount = completedOrderCount
        self.marketingEmailOptIn = marketingEmailOptIn
    }
    
    enum CodingKeys: String, CodingKey {
        case uid, email, displayName, phone, isAdmin, points, createdAt, completedOrderCount, marketingEmailOptIn
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = try c.decode(String.self, forKey: .uid)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        completedOrderCount = try c.decodeIfPresent(Int.self, forKey: .completedOrderCount) ?? 0
        marketingEmailOptIn = try c.decodeIfPresent(Bool.self, forKey: .marketingEmailOptIn) ?? true
    }
}
