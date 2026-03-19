//
//  ProductImageView.swift
//  Guilty Pleasure Treats
//
//  Reusable async image for product photos with placeholder.
//

import SwiftUI

struct ProductImageView: View {
    let urlString: String?
    let placeholderName: String
    var cornerRadius: CGFloat = AppConstants.Layout.cardCornerRadius
    
    var body: some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Image(systemName: placeholderName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: placeholderName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
