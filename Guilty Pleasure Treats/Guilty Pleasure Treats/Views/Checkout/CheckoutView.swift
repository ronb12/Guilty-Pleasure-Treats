//
//  CheckoutView.swift
//  Guilty Pleasure Treats
//
//  Checkout: name, phone, pickup/delivery, date/time, Stripe or Apple Pay.
//

import SwiftUI

/// Wraps order + id for navigation destination.
struct ConfirmedOrderItem: Identifiable {
    let order: Order
    let orderId: String
    var id: String { orderId }
}

struct CheckoutView: View {
    @StateObject private var viewModel = CheckoutViewModel()
    @StateObject private var auth = AuthService.shared
    @State private var selectedPayment: PaymentMethod = .stripe
    @State private var confirmedOrder: ConfirmedOrderItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let msg = viewModel.errorMessage {
                    ErrorMessageBanner(message: msg) {
                        viewModel.errorMessage = nil
                    }
                }
                
                contactSection
                fulfillmentSection
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $confirmedOrder) { item in
            OrderConfirmationView(order: item.order, orderId: item.orderId) {
                confirmedOrder = nil
            }
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Contact")
            TextField("Your name", text: $viewModel.customerName)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.words)
            TextField("Phone number", text: $viewModel.customerPhone)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
    
    private var fulfillmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Pickup or Delivery")
            Picker("", selection: $viewModel.fulfillmentType) {
                ForEach(FulfillmentType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            sectionLabel("Pickup date & time")
            DatePicker("", selection: $viewModel.scheduledDate, in: Date()...)
                .datePickerStyle(.compact)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
    
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Payment")
            Picker("", selection: $selectedPayment) {
                Text("Card (Stripe)").tag(PaymentMethod.stripe)
                Text("Apple Pay").tag(PaymentMethod.applePay)
                Text("Pay at Pickup").tag(PaymentMethod.payAtPickup)
            }
            .pickerStyle(.menu)
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
        let success = await viewModel.placeOrder(paymentMethod: selectedPayment)
        if success,
           let order = viewModel.lastCreatedOrder,
           let orderId = viewModel.lastCreatedOrderId {
            confirmedOrder = ConfirmedOrderItem(order: order, orderId: orderId)
        }
    }
}
