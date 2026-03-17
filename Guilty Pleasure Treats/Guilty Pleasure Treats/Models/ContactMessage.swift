//
//  ContactMessage.swift
//  Guilty Pleasure Treats
//
//  In-app contact form submission. Admin sees these in Admin → Messages.
//

import Foundation

struct ContactMessage: Identifiable, Codable, Equatable {
    var id: String
    var name: String?
    var email: String
    var subject: String?
    var message: String
    var userId: String?
    var readAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, email, subject, message
        case userId = "userId"
        case readAt = "readAt"
        case createdAt = "createdAt"
    }

    static func == (lhs: ContactMessage, rhs: ContactMessage) -> Bool {
        lhs.id == rhs.id
    }
}
