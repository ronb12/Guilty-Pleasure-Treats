//
//  ContactMessage.swift
//  Guilty Pleasure Treats
//
//  In-app contact form submission. Admin sees these in Admin → Messages.
//

import Foundation

private enum GalleryQuoteMessageLines {
    static let photoLinePrefix = "Design photo link (reference):"
}

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

    // MARK: - Gallery quote reference photo (embedded in `message` body)

    /// HTTPS URL from the line `Design photo link (reference): …` in the message body.
    var galleryReferencePhotoURL: URL? {
        let prefix = GalleryQuoteMessageLines.photoLinePrefix
        for line in message.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.count >= prefix.count else { continue }
            guard t.lowercased().hasPrefix(prefix.lowercased()) else { continue }
            let rest = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: rest), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { continue }
            return url
        }
        return nil
    }

    /// Message body for admin UI: drops the photo URL line when we render the image separately.
    var messageTextForAdminDisplay: String {
        guard galleryReferencePhotoURL != nil else { return message }
        let prefixLower = GalleryQuoteMessageLines.photoLinePrefix.lowercased()
        let lines = message.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            !line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix(prefixLower)
        }
        return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
