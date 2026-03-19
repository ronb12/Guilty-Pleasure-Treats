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
    /// When set, the message is about this order; admin can open it from the message.
    var orderId: String?
    var readAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, email, subject, message
        case userId = "userId"
        case orderId = "orderId"
        case readAt = "readAt"
        case createdAt = "createdAt"
    }

    static func == (lhs: ContactMessage, rhs: ContactMessage) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Order reference (admin UI, notifications)

    /// Non-empty trimmed `orderId` from API, if any.
    var linkedOrderId: String? {
        guard let oid = orderId?.trimmingCharacters(in: .whitespacesAndNewlines), !oid.isEmpty else { return nil }
        return oid
    }

    /// Short reference for list rows and badges (first 8 hex chars of UUID, uppercase).
    var orderReferenceShort: String? {
        guard let oid = linkedOrderId else { return nil }
        let compact = oid.replacingOccurrences(of: "-", with: "")
        guard compact.count >= 8 else { return oid }
        return String(compact.prefix(8)).uppercased()
    }
}
