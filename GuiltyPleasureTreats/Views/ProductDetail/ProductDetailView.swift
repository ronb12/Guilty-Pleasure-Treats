//
//  ProductDetailView.swift
//  Guilty Pleasure Treats
//
//  Product detail: image, description, price, quantity, special instructions, Add to Cart.
//

import SwiftUI

struct ProductDetailView: View {
    let product: Product
    @StateObject private var cart = CartManager.shared
    @State private var quantity = 1
    @State private var specialInstructions = ""
    @State private var addedToCart = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProductImageView(urlString: product.imageURL, placeholderName: "cupcake.and.candles.fill")
                    .frame(height: 280)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(product.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    
                    Text(product.productDescription)
                        .font(.body)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                    
                    Text(product.price.currencyFormatted)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConstants.Colors.accent)
                    
                    if product.isSoldOut {
                        Text("Currently sold out")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    } else {
                        quantitySelector
                        specialInstructionsField
                        addToCartButton
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Added to Cart", isPresented: $addedToCart) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(quantity) x \(product.name) added to your cart.")
        }
    }
    
    private var quantitySelector: some View {
        HStack {
            Text("Quantity")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    if quantity > 1 { quantity -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
                Text("\(quantity)")
                    .font(.headline)
                    .frame(minWidth: 32)
                Button {
                    quantity += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
        }
    }
    
    private var specialInstructionsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Special instructions (optional)")
                .font(.caption)
                .foregroundStyle(AppConstants.Colors.textSecondary)
            TextField("e.g. No nuts, extra frosting", text: $specialInstructions, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
    }
    
    private var addToCartButton: some View {
        PrimaryButton(title: "Add to Cart") {
            for _ in 0..<quantity {
                cart.add(product: product, quantity: 1, specialInstructions: specialInstructions)
            }
            addedToCart = true
        }
    }
}
