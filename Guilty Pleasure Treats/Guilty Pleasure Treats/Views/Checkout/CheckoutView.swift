//
//  CheckoutView.swift
//  Guilty Pleasure Treats
//
//  Checkout: name, phone, pickup/delivery, date/time, Stripe.
//

import SwiftUI

/// Wraps order + id + payment method for navigation destination.
struct ConfirmedOrderItem: Identifiable, Hashable {
    let order: Order
    let orderId: String
    let paymentMethod: PaymentMethod
    var id: String { orderId }
    func hash(into hasher: inout Hasher) { hasher.combine(orderId) }
    static func == (lhs: ConfirmedOrderItem, rhs: ConfirmedOrderItem) -> Bool { lhs.orderId == rhs.orderId }
}

struct CheckoutView: View {
    @StateObject private var viewModel = CheckoutViewModel()
    @ObservedObject private var cart = CartManager.shared
    @StateObject private var auth = AuthService.shared
    @State private var confirmedOrder: ConfirmedOrderItem?

    /// iPhone/iPad: always use in-app Stripe after placing the order (Payment Sheet). Mac: pay-by-link only.
    private var checkoutPaymentMethod: PaymentMethod {
        #if os(macOS)
        return .payByLink
        #else
        return .stripe
        #endif
    }

    /// Payment section copy: show Stripe card copy on iOS (checkout always attempts Stripe there).
    private var paymentSectionShowsStripe: Bool {
        #if os(macOS)
        return false
        #else
        return true
        #endif
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let msg = viewModel.errorMessage {
                    ErrorMessageBanner(message: msg, debugCopyText: viewModel.lastErrorDebugText) {
                        viewModel.errorMessage = nil
                        viewModel.lastErrorDebugText = nil
                    }
                }
                if let warn = cart.businessSettingsWarning {
                    settingsWarningBanner(warn)
                }
                Text("Totals below are estimates from your cart and store settings. After you place the order, tax and fees are confirmed by the server and used for payment.")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                contactSection
                fulfillmentSection
                addressSection
                promoSection
                orderSummarySection
                paymentSection
                
                PrimaryButton(
                    title: "Place Order",
                    action: { Task { await placeOrder() } },
                    isLoading: viewModel.isLoading,
                    disabled: !viewModel.canCheckout
                )
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Checkout")
        .inlineNavigationTitle()
        .navigationDestination(item: $confirmedOrder) { item in
            OrderConfirmationView(order: item.order, orderId: item.orderId, paymentMethod: item.paymentMethod) {
                confirmedOrder = nil
            }
        }
        .onAppear {
            if viewModel.customerEmail.isEmpty, let email = auth.currentUser?.email {
                viewModel.customerEmail = email
            }
            let profile = auth.userProfile
            if viewModel.customerName.isEmpty {
                let name = profile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? auth.currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let name, !name.isEmpty { viewModel.customerName = name }
            }
            if viewModel.customerPhone.isEmpty {
                let p = profile?.phone?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? auth.currentUser?.phone?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let p, !p.isEmpty { viewModel.customerPhone = p }
            }
            Task {
                if let settings = try? await VercelService.shared.fetchBusinessSettings() {
                    await MainActor.run {
                        CartManager.shared.applyBusinessSettingsFromServer(settings)
                        if let hours = settings.minimumOrderLeadTimeHours, hours > 0 {
                            viewModel.minimumOrderLeadTimeHours = hours
                            if viewModel.scheduledDate < viewModel.minScheduledDate {
                                viewModel.scheduledDate = viewModel.minScheduledDate
                            }
                        }
                        viewModel.deliveryFee = max(0, settings.deliveryFee ?? 0)
                        let nationwide = max(0, settings.shippingFee ?? 0)
                        viewModel.shippingFeeNationwide = nationwide
                        viewModel.shippingFeeLocal = max(0, settings.shippingFeeLocal ?? nationwide)
                        if let sts = settings.shippingLocalStates, !sts.isEmpty {
                            viewModel.shippingLocalStates = sts.map {
                                String($0.trimmingCharacters(in: .whitespaces).uppercased().prefix(2))
                            }.filter { !$0.isEmpty }
                        } else {
                            viewModel.shippingLocalStates = CheckoutViewModel.defaultShippingLocalStates
                        }
                        CartManager.shared.taxRate = settings.taxRate
                    }
                }
            }
            if viewModel.scheduledDate < viewModel.minScheduledDate {
                viewModel.scheduledDate = viewModel.minScheduledDate
            }
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Contact")
            TextField("Your name", text: $viewModel.customerName)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .autocapitalization(.words)
                #endif
            TextField("Phone number", text: $viewModel.customerPhone)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.phonePad)
                #endif
            TextField("Email (optional — for receipts)", text: $viewModel.customerEmail)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
    
    private var dateTimeLabel: String {
        switch viewModel.fulfillmentType {
        case .pickup: return "Pickup date & time"
        case .delivery: return "Delivery date & time"
        case .shipping: return "Preferred ship date"
        }
    }

    private var fulfillmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Pickup, delivery, or shipping")
            Picker("", selection: $viewModel.fulfillmentType) {
                ForEach(FulfillmentType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            sectionLabel(dateTimeLabel)
            DatePicker("", selection: $viewModel.scheduledDate, in: viewModel.minScheduledDate...)
                .datePickerStyle(.compact)
            Text("Orders require at least \(viewModel.minimumOrderLeadTimeHours) hours notice.")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
    
    @ViewBuilder
    private var addressSection: some View {
        if viewModel.fulfillmentType == .delivery || viewModel.fulfillmentType == .shipping {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(viewModel.fulfillmentType == .shipping ? "Shipping address" : "Delivery address")
                TextField("Street address", text: $viewModel.street)
                    .textFieldStyle(.roundedBorder)
                TextField("Apt, suite, unit (optional)", text: $viewModel.addressLine2)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 12) {
                    TextField("City", text: $viewModel.city)
                        .textFieldStyle(.roundedBorder)
                    TextField("State", text: $viewModel.state)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    TextField("ZIP", text: $viewModel.zip)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .frame(width: 90)
                }
            }
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        }
    }
    
    private func settingsWarningBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(AppConstants.Colors.accent)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Order total (estimate)")
            HStack {
                Text("Subtotal")
                Spacer()
                Text(viewModel.orderSummarySubtotal.currencyFormatted)
            }
            .font(.subheadline)
            .foregroundStyle(AppConstants.Colors.textSecondary)
            if viewModel.orderSummaryDiscount > 0 {
                HStack {
                    Text("Discount")
                    Spacer()
                    Text("-\(viewModel.orderSummaryDiscount.currencyFormatted)")
                        .foregroundStyle(.green)
                }
                .font(.subheadline)
            }
            if viewModel.orderSummaryDeliveryFee > 0 {
                HStack {
                    Text("Delivery fee")
                    Spacer()
                    Text(viewModel.orderSummaryDeliveryFee.currencyFormatted)
                }
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if viewModel.orderSummaryShippingFee > 0 {
                HStack {
                    Text("Shipping fee")
                    Spacer()
                    Text(viewModel.orderSummaryShippingFee.currencyFormatted)
                }
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            HStack {
                Text("Tax")
                Spacer()
                Text(viewModel.orderSummaryTax.currencyFormatted)
            }
            .font(.subheadline)
            .foregroundStyle(AppConstants.Colors.textSecondary)
            if viewModel.orderSummaryTip > 0 {
                HStack {
                    Text("Tip")
                    Spacer()
                    Text(viewModel.orderSummaryTip.currencyFormatted)
                }
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            Divider()
            HStack {
                Text("Total")
                    .fontWeight(.semibold)
                Spacer()
                Text(viewModel.orderSummaryTotal.currencyFormatted)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.accent)
            }
            .font(.subheadline)
            .foregroundStyle(AppConstants.Colors.textPrimary)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
    
    private var promoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Promo code")
            HStack {
                TextField("Enter code", text: $viewModel.promoCode)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .disabled(viewModel.appliedPromotion != nil)
                Button(viewModel.appliedPromotion != nil ? "Remove" : "Apply") {
                    if viewModel.appliedPromotion != nil {
                        viewModel.clearPromoCode()
                    } else {
                        Task { await viewModel.applyPromoCode() }
                    }
                }
                .foregroundStyle(AppConstants.Colors.accent)
                .disabled(viewModel.promoCode.trimmingCharacters(in: .whitespaces).isEmpty && viewModel.appliedPromotion == nil)
            }
            if let blocker = viewModel.promoEligibilityBlocker {
                Text(blocker)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let msg = viewModel.promoMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(viewModel.appliedPromotion != nil ? .green : AppConstants.Colors.textSecondary)
            }
            if viewModel.appliedPromotion != nil, viewModel.discountAmount > 0 {
                Text("Discount: -\(viewModel.discountAmount.currencyFormatted)")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
    
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Payment")
            if paymentSectionShowsStripe {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(AppConstants.Colors.accent)
                    Text("Debit or credit card")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                }
                Text("Checkout is powered by Stripe. After you place your order, you’ll enter your card in the secure payment screen—Visa, Mastercard, Amex, Discover, and most debit cards.")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack {
                    Image(systemName: "link.circle.fill")
                        .foregroundStyle(AppConstants.Colors.accent)
                    Text("Pay by link")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                }
                #if os(macOS)
                Text(
                    cart.stripeCheckoutEnabledFromServer
                        ? "On Mac, card payment is completed through a secure link. Place your order and the shop will send you a payment link by text or email."
                        : "Place your order now. The shop will send you a secure payment link by text or email to pay by card—or enable Stripe in Admin → Business Settings."
                )
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                #else
                Text("Place your order now. The shop will send you a secure payment link by text or email to pay by card—or enable Stripe keys in Admin → Business Settings for in-app checkout.")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                #endif
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }
    
    private func placeOrder() async {
        let success = await viewModel.placeOrder(paymentMethod: checkoutPaymentMethod)
        if success,
           let order = viewModel.lastCreatedOrder,
           let orderId = viewModel.lastCreatedOrderId {
            confirmedOrder = ConfirmedOrderItem(order: order, orderId: orderId, paymentMethod: viewModel.lastPaymentMethod)
        }
    }
}
