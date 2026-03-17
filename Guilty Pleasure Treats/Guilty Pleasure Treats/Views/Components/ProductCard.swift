//
//  ProductCard.swift
//  Guilty Pleasure Treats
//
//  Card-style product cell for menu and featured list.
//

import SwiftUI

struct ProductCard: View {
    let product: Product
    var onTap: (() -> Void)?
    var onAddToCart: (() -> Void)?
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)?

    private var hasImage: Bool { product.imageURL != nil && !(product.imageURL?.isEmpty ?? true) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ProductImageView(urlString: product.imageURL, placeholderName: "cupcake.and.candles.fill")
                    .frame(height: 140)
                    .clipped()
                if onToggleFavorite != nil {
                    Button(action: { onToggleFavorite?() }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(isFavorite ? AppConstants.Colors.accent : AppConstants.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }

            // Info section: always visible below the image so name, description, and price are clear
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if product.isVegetarian {
                        Label("Vegetarian", systemImage: "leaf.fill")
                            .font(.caption2)
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                }

                Text(product.productDescription)
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .lineLimit(hasImage ? 3 : 2)

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
                        .buttonStyle(.plain)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppConstants.Colors.cardBackground)
        }
        .background(AppConstants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}
