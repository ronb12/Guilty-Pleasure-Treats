//
//  AppNotification.swift
//  Guilty Pleasure Treats
//
//  In-app notification item for the notification center (bell).
//

import Foundation

/// Type of notification for routing (new order, message, order status, low stock, new event).
enum AppNotificationType: String, Codable {
    case newOrder = "new_order"
    case newMessage = "new_message"
    case orderStatus = "order_status"
    case lowInventory = "low_inventory"
    case newEvent = "new_event"
    /// Push from server when the store sends a message (`notifyAdminMessage` → `type: admin_message`).
    case storeMessage = "admin_message"
    /// Admin replied on a contact thread (`notifyContactThreadReply` → `type: contact_reply`).
    case contactReply = "contact_reply"
    case loyaltyPoints = "loyalty_points"
    case newCustomCake = "new_custom_cake"
    case newReview = "new_review"
}

struct AppNotification: Identifiable, Codable, Equatable {
    var id: String
    var type: AppNotificationType
    var title: String
    var body: String
    var orderId: String?
    var messageId: String?
    var eventId: String?
    var createdAt: Date
    var read: Bool

    init(
        id: String = UUID().uuidString,
        type: AppNotificationType,
        title: String,
        body: String,
        orderId: String? = nil,
        messageId: String? = nil,
        eventId: String? = nil,
        createdAt: Date = Date(),
        read: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.orderId = orderId
        self.messageId = messageId
        self.eventId = eventId
        self.createdAt = createdAt
        self.read = read
    }

    var systemImage: String {
        switch type {
        case .newOrder: return "cart.badge.plus"
        case .newMessage: return "envelope.badge"
        case .orderStatus: return "doc.text"
        case .lowInventory: return "exclamationmark.triangle"
        case .newEvent: return "calendar.badge.plus"
        case .storeMessage: return "bubble.left.and.bubble.right"
        case .contactReply: return "bubble.left.and.bubble.right.fill"
        case .loyaltyPoints: return "gift.fill"
        case .newCustomCake: return "birthday.cake"
        case .newReview: return "star.fill"
        }
    }
}
