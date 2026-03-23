//
//  CheckoutViewModel.swift
//  Guilty Pleasure Treats
//
//  Handles checkout: create order, Stripe, confirmation.
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
    /// Nationwide / default shipping rate (from business settings `shippingFee`).
    @Published var shippingFeeNationwide: Double = 0
    /// Local-zone shipping rate (from `shippingFeeLocal`, or same as nationwide when unset).
    @Published var shippingFeeLocal: Double = 0
    /// Two-letter state codes for local shipping; empty uses same default as API (`NJ, NY, PA, CT, DE`).
    @Published var shippingLocalStates: [String] = ["NJ", "NY", "PA", "CT", "DE"]

    /// Default local zone when admin leaves the list empty (matches `api/lib/shippingFee.js`).
    static let defaultShippingLocalStates = ["NJ", "NY", "PA", "CT", "DE"]
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
    /// Raw API/support text (shown with Copy in checkout error banner).
    @Published var lastErrorDebugText: String?
    @Published var lastCreatedOrderId: String?
    @Published var lastCreatedOrder: Order?
    @Published var lastPaymentMethod: PaymentMethod = .payAtPickup
    
    private let api = VercelService.shared
    private let cart = CartManager.shared
    private let auth = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    /// Reused until an order succeeds so retries don’t create duplicates (server idempotency).
    private var pendingIdempotencyKey: String?

    init() {
        cart.$taxRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        cart.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Tax rate comes from `CartManager` (single source of truth with cart).
    private var taxRate: Double { cart.taxRate }
    
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

    /// Same rules as `extractStateCodeFromAddress` in `api/lib/shippingFee.js` (last line `City, ST, ZIP`).
    private static func extractStateCodeFromAddress(_ addr: String?) -> String? {
        guard let addr, !addr.isEmpty else { return nil }
        let lines = addr
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let last = lines.last else { return nil }
        let parts = last.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }
        let segment = String(parts[1])
        guard let regex = try? NSRegularExpression(pattern: "^[A-Za-z]{2}\\b") else { return nil }
        let ns = segment as NSString
        guard let match = regex.firstMatch(in: segment, range: NSRange(location: 0, length: ns.length)),
              let range = Range(match.range, in: segment) else { return nil }
        return String(segment[range]).uppercased()
    }

    private var effectiveLocalShippingStates: Set<String> {
        let normalized = shippingLocalStates
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased().prefix(2) }
            .map(String.init)
            .filter { !$0.isEmpty }
        if normalized.isEmpty { return Set(Self.defaultShippingLocalStates) }
        return Set(normalized)
    }

    /// Mirrors `resolveShippingFeeDollars` on the server for the current address.
    var resolvedShippingFee: Double {
        let nationwide = max(0, shippingFeeNationwide)
        let localFee = max(0, shippingFeeLocal)
        guard fulfillmentType == .shipping else { return 0 }
        guard let addr = deliveryAddressString else { return nationwide }
        guard let st = Self.extractStateCodeFromAddress(addr) else { return nationwide }
        return effectiveLocalShippingStates.contains(st) ? localFee : nationwide
    }
    
    // Order summary for display (matches placeOrder math). Tax uses cart.taxRate.
    var orderSummarySubtotal: Double {
        cart.toOrderItems().reduce(0.0) { $0 + $1.subtotal }
    }
    var orderSummaryDiscount: Double { discountAmount }
    var orderSummarySubtotalAfterDiscount: Double { max(0, orderSummarySubtotal - orderSummaryDiscount) }
    var orderSummaryTax: Double { orderSummarySubtotalAfterDiscount * taxRate }
    var orderSummaryTip: Double { cart.tipAmount }
    /// Delivery fee when fulfillment is Delivery.
    var orderSummaryDeliveryFee: Double { fulfillmentType == .delivery ? deliveryFee : 0 }
    /// Shipping fee when fulfillment is Shipping.
    var orderSummaryShippingFee: Double { fulfillmentType == .shipping ? resolvedShippingFee : 0 }
    var orderSummaryTotal: Double {
        orderSummarySubtotalAfterDiscount + orderSummaryTax + orderSummaryTip
            + orderSummaryDeliveryFee + orderSummaryShippingFee
    }
    
    var discountAmount: Double {
        guard let promo = appliedPromotion else { return 0 }
        let subtotal = cart.toOrderItems().reduce(0.0) { $0 + $1.subtotal }
        let qty = cart.itemCount
        let signedIn = auth.currentUser != nil
        let prior = auth.userProfile?.completedOrderCount
        if promo.eligibilityFailureMessage(subtotal: subtotal, totalItemQuantity: qty, signedInUser: signedIn, priorCompletedOrderCount: prior) != nil {
            return 0
        }
        switch promo.discountTypeEnum {
        case .percent:
            return subtotal * (promo.value / 100)
        case .fixed:
            return min(promo.value, subtotal)
        case .none:
            return 0
        }
    }

    /// When a code is applied but cart / account doesn’t meet reward rules (matches server).
    var promoEligibilityBlocker: String? {
        guard let promo = appliedPromotion else { return nil }
        let subtotal = cart.toOrderItems().reduce(0.0) { $0 + $1.subtotal }
        return promo.eligibilityFailureMessage(
            subtotal: subtotal,
            totalItemQuantity: cart.itemCount,
            signedInUser: auth.currentUser != nil,
            priorCompletedOrderCount: auth.userProfile?.completedOrderCount
        )
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
                if promo.firstOrderOnly, auth.currentUser != nil {
                    await auth.refreshProfile()
                }
                appliedPromotion = promo
                let subtotal = cart.toOrderItems().reduce(0.0) { $0 + $1.subtotal }
                let prior = auth.userProfile?.completedOrderCount
                if let blocker = promo.eligibilityFailureMessage(
                    subtotal: subtotal,
                    totalItemQuantity: cart.itemCount,
                    signedInUser: auth.currentUser != nil,
                    priorCompletedOrderCount: prior
                ) {
                    promoMessage = blocker
                } else {
                    promoMessage = "Discount applied — \(promo.code.uppercased())"
                }
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
        let tax = subtotalAfterDiscount * taxRate
        let tip = cart.tipAmount
        let deliveryFeeAmount = fulfillmentType == .delivery ? deliveryFee : 0
        let shippingFeeAmount = fulfillmentType == .shipping ? resolvedShippingFee : 0
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
        let promoForApi: String? = appliedPromotion.map { $0.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }.flatMap { $0.isEmpty ? nil : $0 }
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
            aiCakeDesignIds: aiCakeDesignIds.isEmpty ? nil : aiCakeDesignIds,
            promoCode: promoForApi
        )
        
        isLoading = true
        errorMessage = nil
        lastErrorDebugText = nil
        defer { isLoading = false }
        
        if pendingIdempotencyKey == nil {
            pendingIdempotencyKey = UUID().uuidString
        }
        let idemKey = pendingIdempotencyKey

        #if !os(macOS)
        if paymentMethod == .stripe || paymentMethod == .applePay {
            guard StripeService.canStartCheckout() else {
                errorMessage = "Card payments aren’t set up in this app build. Update the app or contact the shop."
                return false
            }
        }
        #endif
        
        do {
            let created = try await api.createOrder(order, idempotencyKey: idemKey)
            order.id = created.id
            order.subtotal = created.subtotal
            order.tax = created.tax
            order.total = created.total
            let orderId = created.id
            lastPaymentMethod = paymentMethod
            
            switch paymentMethod {
            case .stripe, .applePay:
                let amountCents = Int((order.total * 100).rounded())
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
            
            // Only clear after successful payment flow (or non-Stripe paths) so retries use the same idempotency key.
            pendingIdempotencyKey = nil
            cart.clear()
            lastCreatedOrderId = orderId
            lastCreatedOrder = order
            return true
        } catch {
            if let apiErr = error as? VercelAPIError {
                lastErrorDebugText = apiErr.supportDebugText
            } else {
                lastErrorDebugText = (error as NSError).localizedDescription
            }
            errorMessage = FriendlyErrorMessage.message(for: error)
            return false
        }
    }
    
    func resetAfterConfirmation() {
        lastCreatedOrderId = nil
        lastCreatedOrder = nil
        pendingIdempotencyKey = nil
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
