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
    var isAdmin: Bool
    /// Loyalty points: 1 point per $1 spent. Stored in Firestore.
    var points: Int
    var createdAt: Date?
    
    init(uid: String, email: String? = nil, displayName: String? = nil, isAdmin: Bool = false, points: Int = 0, createdAt: Date? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isAdmin = isAdmin
        self.points = points
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case uid, email, displayName, isAdmin, points, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = try c.decode(String.self, forKey: .uid)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}
