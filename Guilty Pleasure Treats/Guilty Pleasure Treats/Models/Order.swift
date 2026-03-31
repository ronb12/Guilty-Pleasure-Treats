//
//  Order.swift
//  Guilty Pleasure Treats
//
//  Order model for pickup/delivery with items and payment info.
//

import Foundation

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case preparing = "Preparing"
    case ready = "Ready for Pickup"
    /// Hand-off complete: local delivery dropped off or parcel marked delivered (before `Completed` closes the order).
    case delivered = "Delivered"
    case completed = "Completed"
    case cancelled = "Cancelled"

    /// UI + admin picker label, accounting for fulfillment (same `ready` DB value → Shipped vs Out for delivery vs Ready for pickup).
    func displayLabel(for fulfillment: FulfillmentType?) -> String {
        switch self {
        case .ready:
            switch fulfillment {
            case .shipping: return "Shipped"
            case .delivery: return "Out for delivery"
            case .pickup, .none: return "Ready for pickup"
            }
        case .delivered: return "Delivered"
        default: return rawValue
        }
    }
}

enum FulfillmentType: String, Codable, CaseIterable {
    case pickup = "Pickup"
    case delivery = "Delivery"
    case shipping = "Shipping"
}

/// Order item snapshot (product info at time of order).
struct OrderItem: Codable, Identifiable, Equatable {
    var id: String
    var productId: String
    var name: String
    var price: Double
    var quantity: Int
    var specialInstructions: String
    /// When set (e.g. "Small"), shown on receipts and admin order detail.
    var sizeLabel: String?

    var subtotal: Double { price * Double(quantity) }

    enum CodingKeys: String, CodingKey {
        case id
        case productId
        case name
        case price
        case quantity
        case specialInstructions
        case sizeLabel
    }

    init(
        id: String,
        productId: String,
        name: String,
        price: Double,
        quantity: Int,
        specialInstructions: String,
        sizeLabel: String? = nil
    ) {
        self.id = id
        self.productId = productId
        self.name = name
        self.price = price
        self.quantity = quantity
        self.specialInstructions = specialInstructions
        self.sizeLabel = sizeLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        productId = try c.decodeIfPresent(String.self, forKey: .productId) ?? ""
        name = try c.decode(String.self, forKey: .name)
        price = try c.decode(Double.self, forKey: .price)
        quantity = try c.decode(Int.self, forKey: .quantity)
        specialInstructions = try c.decodeIfPresent(String.self, forKey: .specialInstructions) ?? ""
        sizeLabel = try c.decodeIfPresent(String.self, forKey: .sizeLabel)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(productId, forKey: .productId)
        try c.encode(name, forKey: .name)
        try c.encode(price, forKey: .price)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(specialInstructions, forKey: .specialInstructions)
        try c.encodeIfPresent(sizeLabel, forKey: .sizeLabel)
    }
}

struct Order: Identifiable, Codable, Equatable {
    var id: String?
    var userId: String?
    var customerName: String
    var customerPhone: String
    var customerEmail: String? = nil
    /// Customer food allergy notes (from profile at checkout). Shown on admin order detail.
    var customerAllergies: String? = nil
    var deliveryAddress: String? = nil
    var items: [OrderItem]
    var subtotal: Double
    var tax: Double
    var total: Double
    var fulfillmentType: String
    var scheduledPickupDate: Date?
    var status: String
    var stripePaymentIntentId: String?
    /// Set when owner records receiving cash/card/check/Cash App payment in person.
    var manualPaidAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var estimatedReadyTime: Date?
    /// Document IDs of custom cake orders included in this order.
    var customCakeOrderIds: [String]?
    /// Document IDs of AI cake designs included in this order.
    var aiCakeDesignIds: [String]?
    /// Sent to API when a promo discount is applied (server validates).
    var promoCode: String? = nil
    /// Tip amount in cents (from cart at checkout). Omitted in older API responses.
    var tipCents: Int? = nil
    /// User loyalty points (from users table, admin requests only). Omitted in older API responses.
    var userPoints: Int? = nil
    /// Parcel carrier for shipped orders: `ups`, `fedex`, or `usps` (server-normalized).
    var trackingCarrier: String? = nil
    var trackingNumber: String? = nil
    var trackingStatusDetail: String? = nil
    var trackingUpdatedAt: Date? = nil
    /// Public carrier track page URL when carrier and number are set (server-computed).
    var trackingUrl: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case customerName
        case customerPhone
        case customerEmail
        case customerAllergies
        case deliveryAddress
        case items
        case subtotal
        case tax
        case total
        case fulfillmentType
        case scheduledPickupDate
        case status
        case stripePaymentIntentId
        case manualPaidAt
        case createdAt
        case updatedAt
        case estimatedReadyTime
        case customCakeOrderIds
        case aiCakeDesignIds
        case promoCode
        case tipCents
        case userPoints
        case trackingCarrier
        case trackingNumber
        case trackingStatusDetail
        case trackingUpdatedAt
        case trackingUrl
    }
    
    /// True if order was paid via Stripe or marked paid manually.
    var isPaid: Bool {
        (stripePaymentIntentId != nil && !(stripePaymentIntentId?.isEmpty ?? true)) || manualPaidAt != nil
    }
    
    var statusEnum: OrderStatus? { OrderStatus(rawValue: status) }
    var fulfillmentEnum: FulfillmentType? { FulfillmentType(rawValue: fulfillmentType) }

    /// Customer- and admin-friendly status line (uses fulfillment for the `ready` step).
    var statusDisplayLabel: String {
        guard let e = statusEnum else { return status }
        return e.displayLabel(for: fulfillmentEnum)
    }

    /// True when both carrier and tracking number are set (required server-side before marking a shipping order ready).
    var hasParcelTrackingForShipping: Bool {
        guard let c = trackingCarrier?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty else { return false }
        guard let n = trackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return false }
        return true
    }

    // MARK: - Totals breakdown (shipping/delivery + tip are folded into `total`, not separate DB columns)

    /// Tip from checkout, in dollars (`tip_cents` from API).
    var tipAmountDollars: Double {
        guard let c = tipCents, c > 0 else { return 0 }
        return Double(c) / 100
    }

    /// Portion of `total` after subtotal, tax, and tip — matches server `deliveryFee` / `shippingFee` for Delivery/Shipping.
    var fulfillmentFeeDollars: Double {
        max(0, total - subtotal - tax - tipAmountDollars)
    }

    /// Row label for `fulfillmentFeeDollars` in receipts and order detail.
    var fulfillmentFeeLineLabel: String {
        switch fulfillmentEnum {
        case .delivery: return "Delivery fee"
        case .shipping: return "Shipping"
        case .pickup, .none: return "Fees"
        }
    }
}
