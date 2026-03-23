//
//  ProductImageView.swift
//  Guilty Pleasure Treats
//
//  Reusable async image for product photos with placeholder.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ProductImageView: View {
    let urlString: String?
    let placeholderName: String
    var cornerRadius: CGFloat = AppConstants.Layout.cardCornerRadius

    private var safePlaceholderName: String {
        #if os(iOS)
        return UIImage(systemName: placeholderName) != nil ? placeholderName : "photo"
        #elseif os(macOS)
        return NSImage(systemSymbolName: placeholderName, accessibilityDescription: nil) != nil ? placeholderName : "photo"
        #else
        return placeholderName
        #endif
    }
    
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
                        Image(systemName: safePlaceholderName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: safePlaceholderName)
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
