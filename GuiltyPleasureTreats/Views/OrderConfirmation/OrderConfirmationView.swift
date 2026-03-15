//
//  OrderConfirmationView.swift
//  Guilty Pleasure Treats
//
//  Order summary and estimated pickup time after checkout.
//

import SwiftUI

struct OrderConfirmationView: View {
    let order: Order
    let orderId: String
    var onDismiss: (() -> Void)?
    @StateObject private var viewModel = CheckoutViewModel()
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
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Order #")
                        Spacer()
                        Text(orderId.prefix(8))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    
                    if let date = order.scheduledPickupDate {
                        HStack {
                            Text("Pickup time")
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
                        HStack {
                            Text("\(item.quantity)x \(item.name)")
                            Spacer()
                            Text(item.subtotal.currencyFormatted)
                        }
                        .font(.subheadline)
                    }
                    
                    Divider()
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(order.total.currencyFormatted)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}
