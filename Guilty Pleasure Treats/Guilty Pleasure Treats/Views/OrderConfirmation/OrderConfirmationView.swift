//
//  OrderConfirmationView.swift
//  Guilty Pleasure Treats
//
//  Order summary and estimated pickup time after checkout. Shows Cash App / QR pay when that option was selected.
//

import SwiftUI

struct OrderConfirmationView: View {
    let order: Order
    let orderId: String
    var paymentMethod: PaymentMethod = .payAtPickup
    var onDismiss: (() -> Void)?
    @StateObject private var viewModel = CheckoutViewModel()
    @State private var businessSettings: BusinessSettings?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                
                Text("Order Confirmed!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                
                Text("Thank you for your order. We'll notify you when it's ready.")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                if paymentMethod == .payByLink {
                    Text("You'll receive a secure payment link by text or email to pay by card. Complete payment when you get the link.")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if paymentMethod == .cashApp, let settings = businessSettings, let tag = settings.cashAppTag, !tag.isEmpty {
                    cashAppPaySection(tag: tag)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Order")
                        Spacer()
                        Text(OrderReference.displayCode(from: orderId))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    
                    if let date = order.fulfillmentScheduledDateForDisplay {
                        HStack {
                            Text(order.fulfillmentEnum == .shipping ? "Ship date" : (order.fulfillmentEnum == .delivery ? "Delivery date" : "Pickup time"))
                            Spacer()
                            Text(date.dateAndTimeString)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                    
                    if let ready = order.estimatedReadyTime {
                        HStack {
                            Text("Est. ready")
                            Spacer()
                            Text(ready.dateAndTimeString)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                    
                    Divider()
                    
                    ForEach(order.items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(item.quantity)x \(item.name)")
                                Spacer()
                                Text(item.subtotal.currencyFormatted)
                            }
                            .font(.subheadline)
                            if let s = item.sizeLabel, !s.isEmpty {
                                Text(s)
                                    .font(.caption2)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                        }
                    }
                    
                    Divider()
                    OrderTotalsBreakdownView(order: order, emphasizeTotal: false)
                    Text("This total was confirmed by the store when your order was placed and is what payment is based on.")
                        .font(.caption2)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding()
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                
                PrimaryButton(title: "Back to Home") {
                    viewModel.resetAfterConfirmation()
                    onDismiss?()
                    dismiss()
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Confirmation")
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden(true)
        .task {
            if paymentMethod == .cashApp {
                businessSettings = try? await VercelService.shared.fetchBusinessSettings()
            }
        }
    }
    
    private func cashAppPaySection(tag: String) -> some View {
        let normalizedTag = tag.hasPrefix("$") ? tag : "$\(tag)"
        let payURL = "https://cash.app/\(normalizedTag.dropFirst())"
        return VStack(spacing: 12) {
            Text("Pay with Cash App")
                .font(.headline)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text("Scan the code or open Cash App and send the amount to \(normalizedTag)")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Text("Amount: \(order.total.currencyFormatted)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.accent)
            QRCodeView(content: payURL, size: 180)
            if let url = URL(string: payURL) {
                Link("Open in Cash App", destination: url)
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.accent)
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
}
