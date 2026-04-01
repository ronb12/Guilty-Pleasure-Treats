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
    /// From API when submitted as gallery quote (`gallery_quote`).
    var source: String?
    /// Gallery design title when `source` is `gallery_quote`.
    var galleryItemTitle: String?
    var readAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, email, subject, message
        case userId = "userId"
        case orderId = "orderId"
        case source
        case galleryItemTitle = "galleryItemTitle"
        case readAt = "readAt"
        case createdAt = "createdAt"
    }

    /// Gallery “Request a quote” thread (Admin → Quotes).
    var isGalleryQuote: Bool {
        (source ?? "").lowercased() == "gallery_quote"
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

    /// Brand-facing order code for list rows and badges (e.g. GPT-A1B2C3D4).
    var orderReferenceShort: String? {
        guard let oid = linkedOrderId else { return nil }
        return OrderReference.displayCode(from: oid)
    }
}
