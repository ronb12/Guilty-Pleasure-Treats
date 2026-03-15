//
//  CartView.swift
//  Guilty Pleasure Treats
//
//  Cart: list items, quantity controls, total, checkout.
//

import SwiftUI

struct CartView: View {
    @StateObject private var cart = CartManager.shared
    @State private var showCheckout = false
    
    var body: some View {
        Group {
            if cart.isEmpty {
                emptyCartView
            } else {
                cartContentView
            }
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showCheckout) {
            CheckoutView()
        }
    }
    
    private var emptyCartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text("Your cart is empty")
                .font(.title3)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text("Browse our menu to add treats!")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var cartContentView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(cart.items) { item in
                    CartRowView(item: item) {
                        cart.updateQuantity(for: item.id, quantity: item.quantity - 1)
                    } onIncrement: {
                        cart.updateQuantity(for: item.id, quantity: item.quantity + 1)
                    } onRemove: {
                        cart.remove(itemId: item.id)
                    }
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(cart.subtotal.currencyFormatted)
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    HStack {
                        Text("Tax")
                        Spacer()
                        Text(cart.tax.currencyFormatted)
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    Divider()
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(cart.total.currencyFormatted)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
                .padding()
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                
                PrimaryButton(title: "Checkout") {
                    showCheckout = true
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
    }
}

/// Single row in cart with quantity stepper and remove.
struct CartRowView: View {
    let item: CartItem
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProductImageView(urlString: item.product.imageURL, placeholderName: "cupcake.and.candles.fill")
                .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                if !item.specialInstructions.isEmpty {
                    Text(item.specialInstructions)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .lineLimit(1)
                }
                Text(item.subtotal.currencyFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.Colors.accent)
                
                HStack(spacing: 8) {
                    Button(action: onDecrement) {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    Text("\(item.quantity)")
                        .font(.subheadline)
                        .frame(minWidth: 24)
                    Button(action: onIncrement) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}
