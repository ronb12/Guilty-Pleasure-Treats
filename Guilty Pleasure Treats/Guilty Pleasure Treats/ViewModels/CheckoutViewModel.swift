//
//  CheckoutViewModel.swift
//  Guilty Pleasure Treats
//
//  Handles checkout: create order, Stripe/Apple Pay, confirmation.
//

import Foundation
import Combine

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var customerName = ""
    @Published var customerPhone = ""
    @Published var customerEmail = ""
    @Published var fulfillmentType: FulfillmentType = .pickup
    @Published var scheduledDate: Date = {
        let min = Calendar.current.date(byAdding: .hour, value: AppConstants.minimumOrderLeadTimeHours, to: Date()) ?? Date()
        return min
    }()
    /// From business settings (admin). Defaults to AppConstants until settings are loaded.
    @Published var minimumOrderLeadTimeHours: Int = AppConstants.minimumOrderLeadTimeHours
    /// Delivery fee in dollars (from business settings). Applied when fulfillment is Delivery.
    @Published var deliveryFee: Double = 0
    /// Shipping fee in dollars (from business settings). Applied when fulfillment is Shipping.
    @Published var shippingFee: Double = 0
    @Published var street = ""
    @Published var addressLine2 = ""
    @Published var city = ""
    @Published var state = ""
    @Published var zip = ""
    @Published var promoCode = ""
    @Published var appliedPromotion: Promotion?
    @Published var promoMessage: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCreatedOrderId: String?
    @Published var lastCreatedOrder: Order?
    @Published var lastPaymentMethod: PaymentMethod = .payAtPickup
    
    private let api = VercelService.shared
    private let cart = CartManager.shared
    private let auth = AuthService.shared
    
    /// Earliest date/time the customer can select (now + minimum lead time). Prevents impossible last-minute requests.
    var minScheduledDate: Date {
        Calendar.current.date(byAdding: .hour, value: minimumOrderLeadTimeHours, to: Date()) ?? Date()
    }

    var canCheckout: Bool {
        guard !customerName.trimmingCharacters(in: .whitespaces).isEmpty,
              !customerPhone.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if fulfillmentType == .delivery || fulfillmentType == .shipping {
            return !street.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !city.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !state.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !zip.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }
    
    /// Formatted address for API (delivery/shipping only).
    var deliveryAddressString: String? {
        guard fulfillmentType == .delivery || fulfillmentType == .shipping else { return nil }
        let parts = [
            street.trimmingCharacters(in: .whitespaces),
            addressLine2.trimmingCharacters(in: .whitespaces),
            [city.trimmingCharacters(in: .whitespaces), state.trimmingCharacters(in: .whitespaces), zip.trimmingCharacters(in: .whitespaces)].filter { !$0.isEmpty }.joined(separator: ", ")
        ].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
    
    // Order summary for display (matches placeOrder math).
    var orderSummarySubtotal: Double {
        cart.toOrderItems().reduce(0.0) { $0 + $1.subtotal }
    }
    var orderSummaryDiscount: Double { discountAmount }
    var orderSummarySubtotalAfterDiscount: Double { max(0, orderSummarySubtotal - orderSummaryDiscount) }
    var orderSummaryTax: Double { orderSummarySubtotalAfterDiscount * AppConstants.taxRate }
    var orderSummaryTip: Double { cart.tipAmount }
    /// Delivery fee when fulfillment is Delivery.
    var orderSummaryDeliveryFee: Double { fulfillmentType == .delivery ? deliveryFee : 0 }
    /// Shipping fee when fulfillment is Shipping.
    var orderSummaryShippingFee: Double { fulfillmentType == .shipping ? shippingFee : 0 }
    var orderSummaryTotal: Double {
        orderSummarySubtotalAfterDiscount + orderSummaryTax + orderSummaryTip
            + orderSummaryDeliveryFee + orderSummaryShippingFee
    }
    
    var discountAmount: Double {
        guard let promo = appliedPromotion else { return 0 }
        let subtotal = cart.toOrderItems().reduce(0.0) { $0 + $1.subtotal }
        switch promo.discountTypeEnum {
        case .percent:
            return subtotal * (promo.value / 100)
        case .fixed:
            return min(promo.value, subtotal)
        case .none:
            return 0
        }
    }
    
    func applyPromoCode() async {
        let code = promoCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else {
            appliedPromotion = nil
            promoMessage = nil
            return
        }
        do {
            if let promo = try await api.fetchPromotion(byCode: code) {
                appliedPromotion = promo
                promoMessage = "Applied: \(promo.code)"
            } else {
                appliedPromotion = nil
                promoMessage = "Invalid or expired code."
            }
        } catch {
            appliedPromotion = nil
            promoMessage = FriendlyErrorMessage.message(for: error)
        }
    }
    
    func clearPromoCode() {
        promoCode = ""
        appliedPromotion = nil
        promoMessage = nil
    }
    
    func placeOrder(paymentMethod: PaymentMethod) async -> Bool {
        guard canCheckout else {
            if fulfillmentType == .delivery || fulfillmentType == .shipping {
                errorMessage = "Please enter name, phone, and full delivery address."
            } else {
                errorMessage = "Please enter name and phone number."
            }
            return false
        }
        let orderItems = cart.toOrderItems()
        guard !orderItems.isEmpty else {
            errorMessage = "Your cart is empty."
            return false
        }
        
        let subtotal = orderItems.reduce(0) { $0 + $1.subtotal }
        let discount = discountAmount
        let subtotalAfterDiscount = max(0, subtotal - discount)
        let taxRate = AppConstants.taxRate
        let tax = subtotalAfterDiscount * taxRate
        let tip = cart.tipAmount
        let deliveryFeeAmount = fulfillmentType == .delivery ? deliveryFee : 0
        let shippingFeeAmount = fulfillmentType == .shipping ? shippingFee : 0
        let total = subtotalAfterDiscount + tax + tip + deliveryFeeAmount + shippingFeeAmount
        
        let customCakeOrderIds = cart.items.compactMap { item -> String? in
            guard let id = item.product.id, id.hasPrefix("custom-") else { return nil }
            return String(id.dropFirst("custom-".count))
        }
        let aiCakeDesignIds = cart.items.compactMap { item -> String? in
            guard let id = item.product.id, id.hasPrefix("aicake-") else { return nil }
            return String(id.dropFirst("aicake-".count))
        }
        
        let emailToUse = customerEmail.trimmingCharacters(in: .whitespaces).isEmpty ? auth.currentUser?.email : customerEmail.trimmingCharacters(in: .whitespaces)
        var order = Order(
            id: nil,
            userId: auth.currentUser?.uid,
            customerName: customerName.trimmingCharacters(in: .whitespaces),
            customerPhone: customerPhone.trimmingCharacters(in: .whitespaces),
            customerEmail: emailToUse?.isEmpty == true ? nil : emailToUse,
            deliveryAddress: deliveryAddressString,
            items: orderItems,
            subtotal: subtotalAfterDiscount,
            tax: tax,
            total: total,
            fulfillmentType: fulfillmentType.rawValue,
            scheduledPickupDate: scheduledDate,
            status: OrderStatus.pending.rawValue,
            stripePaymentIntentId: nil,
            createdAt: nil,
            updatedAt: nil,
            estimatedReadyTime: nil,
            customCakeOrderIds: customCakeOrderIds.isEmpty ? nil : customCakeOrderIds,
            aiCakeDesignIds: aiCakeDesignIds.isEmpty ? nil : aiCakeDesignIds
        )
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let orderId = try await api.createOrder(order)
            order.id = orderId
            lastPaymentMethod = paymentMethod
            
            switch paymentMethod {
            case .stripe, .applePay:
                let amountCents = Int(total * 100)
                try await StripeService.shared.presentPaymentSheet(
                    amountCents: amountCents,
                    orderId: orderId,
                    customerName: order.customerName,
                    customerEmail: order.customerEmail
                )
            case .payByLink, .payAtPickup, .cashApp:
                // Pay by link: owner sends Stripe link from Admin; customer pays in browser. No in-app payment.
                break
            }
            
            cart.clear()
            lastCreatedOrderId = orderId
            lastCreatedOrder = order
            return true
        } catch {
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }
    
    func resetAfterConfirmation() {
        lastCreatedOrderId = nil
        lastCreatedOrder = nil
        customerName = ""
        customerPhone = ""
        customerEmail = ""
        scheduledDate = Date()
        fulfillmentType = .pickup
        street = ""
        addressLine2 = ""
        city = ""
        state = ""
        zip = ""
        clearPromoCode()
    }
}

enum PaymentMethod {
    /// Owner sends a Stripe payment link (from Admin); customer pays in browser. No in-app card collection.
    case payByLink
    /// Pay by card in the app now (Stripe Payment Sheet).
    case stripe
    case applePay
    case payAtPickup
    /// Pay via Cash App / Venmo QR or link (owner sets tag in Business Settings).
    case cashApp
}
