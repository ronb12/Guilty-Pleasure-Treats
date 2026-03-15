//
//  ProductCard.swift
//  Guilty Pleasure Treats
//
//  Card-style product cell for menu and featured list.
//

import SwiftUI

struct ProductCard: View {
    let product: Product
    var onAddToCart: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProductImageView(urlString: product.imageURL, placeholderName: "cupcake.and.candles.fill")
                .frame(height: 140)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(product.productDescription)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .lineLimit(2)
                
                HStack {
                    Text(product.price.currencyFormatted)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConstants.Colors.accent)
                    Spacer()
                    if let onAddToCart = onAddToCart, !product.isSoldOut {
                        Button(action: onAddToCart) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                    }
                    if product.isSoldOut {
                        Text("Sold Out")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
            }
            .padding(AppConstants.Layout.cardPadding)
        }
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
