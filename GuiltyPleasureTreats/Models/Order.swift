//
//  Order.swift
//  Guilty Pleasure Treats
//
//  Order model for pickup/delivery with items and payment info.
//

import Foundation
import FirebaseFirestore

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case preparing = "Preparing"
    case ready = "Ready for Pickup"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

enum FulfillmentType: String, Codable, CaseIterable {
    case pickup = "Pickup"
    case delivery = "Delivery"
}

/// Order item snapshot (product info at time of order).
struct OrderItem: Codable, Identifiable {
    var id: String
    var productId: String
    var name: String
    var price: Double
    var quantity: Int
    var specialInstructions: String
    
    var subtotal: Double { price * Double(quantity) }
}

struct Order: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String?
    var customerName: String
    var customerPhone: String
    var items: [OrderItem]
    var subtotal: Double
    var tax: Double
    var total: Double
    var fulfillmentType: String
    var scheduledPickupDate: Date?
    var status: String
    var stripePaymentIntentId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var estimatedReadyTime: Date?
    /// Document IDs of custom cake orders included in this order.
    var customCakeOrderIds: [String]?
    /// Document IDs of AI cake designs included in this order.
    var aiCakeDesignIds: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case customerName
        case customerPhone
        case items
        case subtotal
        case tax
        case total
        case fulfillmentType
        case scheduledPickupDate
        case status
        case stripePaymentIntentId
        case createdAt
        case updatedAt
        case estimatedReadyTime
        case customCakeOrderIds
        case aiCakeDesignIds
    }
    
    var statusEnum: OrderStatus? { OrderStatus(rawValue: status) }
    var fulfillmentEnum: FulfillmentType? { FulfillmentType(rawValue: fulfillmentType) }
}
