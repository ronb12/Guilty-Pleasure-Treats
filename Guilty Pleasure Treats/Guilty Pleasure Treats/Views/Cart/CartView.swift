//
//  CartView.swift
//  Guilty Pleasure Treats
//
//  Cart: list items, quantity controls, total, checkout.
//

import SwiftUI

struct CartView: View {
    @StateObject private var cart = CartManager.shared
    @ObservedObject private var tabRouter = TabRouter.shared
    @State private var showCheckout = false
    @State private var customTipText = ""

    var body: some View {
        Group {
            if cart.isEmpty {
                emptyCartView
            } else {
                cartContentView
            }
        }
        .background(AppConstants.Colors.secondary)
        .macOSConstrainedContent()
        .navigationTitle("Cart")
        .inlineNavigationTitle()
        .navigationDestination(isPresented: $showCheckout) {
            CheckoutView()
        }
    }
    
    private var emptyCartView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Text("Your cart is empty")
                .font(.title3)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Text("Browse our menu to add treats!")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            Button {
                tabRouter.switchToMenu()
            } label: {
                Label("Continue Shopping", systemImage: "bag.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppConstants.Colors.accent)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(AppConstants.Colors.accent)
                Text("Add a tip")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            HStack(spacing: 8) {
                tipButton(label: "No tip") { cart.setTipAmount(0); customTipText = "" }
                tipButton(label: "15%") { cart.setTipAmount(cart.subtotal * 0.15); customTipText = "" }
                tipButton(label: "18%") { cart.setTipAmount(cart.subtotal * 0.18); customTipText = "" }
                tipButton(label: "20%") { cart.setTipAmount(cart.subtotal * 0.20); customTipText = "" }
            }
            HStack(spacing: 8) {
                Text("$")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                TextField("Custom amount", text: $customTipText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .font(.subheadline)
                    .padding(8)
                    .background(platformSystemGrayBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: customTipText) { _, newValue in
                        let value = Double(newValue.replacingOccurrences(of: ",", with: "")) ?? 0
                        cart.setTipAmount(value)
                    }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }

    private func tipButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppConstants.Colors.accent.opacity(0.15))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
                
                tipSection

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
                    if cart.tipAmount > 0 {
                        HStack {
                            Text("Tip")
                            Spacer()
                            Text(cart.tipAmount.currencyFormatted)
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
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

                Button {
                    tabRouter.switchToMenu()
                } label: {
                    HStack {
                        Image(systemName: "bag.fill")
                        Text("Continue Shopping")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppConstants.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .padding(.top, 4)

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

    /// Same product image as menu/detail: use shared ProductImageView so thumbnails load consistently.
    private var cartItemThumbnail: some View {
        ProductImageView(urlString: item.product.imageURL, placeholderName: "cupcake.and.candles.fill")
            .frame(width: 80, height: 80)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            cartItemThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}
