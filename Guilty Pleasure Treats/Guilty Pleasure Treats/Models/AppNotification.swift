//
//  AppNotification.swift
//  Guilty Pleasure Treats
//
//  In-app notification item for the notification center (bell).
//

import Foundation

/// Type of notification for routing (new order, message, order status, low stock).
enum AppNotificationType: String, Codable {
    case newOrder = "new_order"
    case newMessage = "new_message"
    case orderStatus = "order_status"
    case lowInventory = "low_inventory"
}

struct AppNotification: Identifiable, Codable, Equatable {
    var id: String
    var type: AppNotificationType
    var title: String
    var body: String
    var orderId: String?
    var messageId: String?
    var createdAt: Date
    var read: Bool

    init(
        id: String = UUID().uuidString,
        type: AppNotificationType,
        title: String,
        body: String,
        orderId: String? = nil,
        messageId: String? = nil,
        createdAt: Date = Date(),
        read: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.orderId = orderId
        self.messageId = messageId
        self.createdAt = createdAt
        self.read = read
    }

    var systemImage: String {
        switch type {
        case .newOrder: return "cart.badge.plus"
        case .newMessage: return "envelope.badge"
        case .orderStatus: return "doc.text"
        case .lowInventory: return "exclamationmark.triangle"
        }
    }
}
