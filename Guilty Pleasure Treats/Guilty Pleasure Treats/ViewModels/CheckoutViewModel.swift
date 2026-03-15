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
    @Published var fulfillmentType: FulfillmentType = .pickup
    @Published var scheduledDate = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCreatedOrderId: String?
    @Published var lastCreatedOrder: Order?
    
    private let firebase = FirebaseService.shared
    private let cart = CartManager.shared
    private let auth = AuthService.shared
    
    var canCheckout: Bool {
        !customerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !customerPhone.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func placeOrder(paymentMethod: PaymentMethod) async -> Bool {
        guard canCheckout else {
            errorMessage = "Please enter name and phone number."
            return false
        }
        let orderItems = cart.toOrderItems()
        guard !orderItems.isEmpty else {
            errorMessage = "Your cart is empty."
            return false
        }
        
        let subtotal = orderItems.reduce(0) { $0 + $1.subtotal }
        let tax = subtotal * AppConstants.taxRate
        let total = subtotal + tax
        
        let customCakeOrderIds = cart.items.compactMap { item -> String? in
            guard let id = item.product.id, id.hasPrefix("custom-") else { return nil }
            return String(id.dropFirst("custom-".count))
        }
        let aiCakeDesignIds = cart.items.compactMap { item -> String? in
            guard let id = item.product.id, id.hasPrefix("aicake-") else { return nil }
            return String(id.dropFirst("aicake-".count))
        }
        
        var order = Order(
            id: nil,
            userId: auth.currentUser?.uid,
            customerName: customerName.trimmingCharacters(in: .whitespaces),
            customerPhone: customerPhone.trimmingCharacters(in: .whitespaces),
            items: orderItems,
            subtotal: subtotal,
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
            let orderId = try await firebase.createOrder(order)
            order.id = orderId
            
            switch paymentMethod {
            case .stripe, .applePay:
                let amountCents = Int(total * 100)
                try await StripeService.shared.presentPaymentSheet(
                    amountCents: amountCents,
                    orderId: orderId,
                    customerName: order.customerName,
                    customerEmail: auth.currentUser?.email
                )
            case .payAtPickup:
                break
            }
            
            cart.clear()
            lastCreatedOrderId = orderId
            lastCreatedOrder = order
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func resetAfterConfirmation() {
        lastCreatedOrderId = nil
        lastCreatedOrder = nil
        customerName = ""
        customerPhone = ""
        scheduledDate = Date()
        fulfillmentType = .pickup
    }
}

enum PaymentMethod {
    case stripe
    case applePay
    case payAtPickup
}
