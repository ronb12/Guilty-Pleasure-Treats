//
//  CakeGalleryView.swift
//  Guilty Pleasure Treats
//
//  Gallery of owner-showcased cakes. Tap to see details and add to order.
//

import SwiftUI

struct CakeGalleryView: View {
    @StateObject private var viewModel = CakeGalleryViewModel()
    @State private var selectedItem: GalleryCakeItem?

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.items.isEmpty {
                ProgressView("Loading gallery…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "We're adding new treats soon",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Check back for cakes, cookies, cupcakes, and more. You'll be able to order something just like what you see.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 160), spacing: 16)
                    ], spacing: 16) {
                        ForEach(viewModel.items) { item in
                            GalleryCard(item: item) {
                                selectedItem = item
                            }
                        }
                    }
                    .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Gallery")
        .inlineNavigationTitle()
        .refreshable { await viewModel.load() }
        .onAppear { Task { await viewModel.load() } }
        .sheet(item: $selectedItem) { item in
            GalleryDetailSheet(
                item: item,
                onAddToCart: {
                    Task {
                        await viewModel.orderItem(item)
                        selectedItem = nil
                    }
                }
            )
        }
        .alert("Added to Cart", isPresented: $viewModel.addedToCart) {
            Button("OK", role: .cancel) { viewModel.addedToCart = false }
        } message: {
            Text("This item has been added to your cart.")
        }
        .overlay(alignment: .top) {
            if let msg = viewModel.errorMessage {
                ErrorMessageBanner(message: msg) { viewModel.errorMessage = nil }
                    .padding()
            }
        }
    }
}

struct GalleryCard: View {
    let item: GalleryCakeItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        default:
                            Rectangle()
                                .fill(AppConstants.Colors.cardBackground)
                                .overlay(ProgressView())
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                }
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                    .lineLimit(2)
                if let cat = item.category, !cat.isEmpty {
                    Text(cat)
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.accent)
                }
                if let p = item.price {
                    Text(p.currencyFormatted)
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.accent)
                } else {
                    Text("Price on request")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct GalleryDetailSheet: View {
    let item: GalleryCakeItem
    /// When the item has a list price — add AI design line to cart at that price.
    var onAddToCart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showQuoteContact = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let urlString = item.imageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            default:
                                Rectangle()
                                    .fill(AppConstants.Colors.cardBackground)
                                    .overlay(ProgressView())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                        if let desc = item.description, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                        if let p = item.price {
                            Text(p.currencyFormatted)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppConstants.Colors.accent)
                        } else {
                            Text("Custom pricing")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                            Text("We’ll confirm details and price after you reach out.")
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                    }
                    if item.price != nil {
                        PrimaryButton(title: "Add to cart", action: {
                            onAddToCart()
                            dismiss()
                        })
                    } else {
                        PrimaryButton(title: "Request a quote", action: {
                            showQuoteContact = true
                        })
                    }
                }
                .padding(AppConstants.Layout.screenHorizontalPadding)
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Details")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
            .sheet(isPresented: $showQuoteContact) {
                ContactView(
                    initialSubject: "Quote: \(item.title)",
                    initialMessage: Self.quoteMessageBody(for: item),
                    messageSource: "gallery_quote",
                    galleryItemTitle: item.title
                )
            }
        }
    }

    private static func quoteMessageBody(for item: GalleryCakeItem) -> String {
        var lines: [String] = [
            "I’m interested in a custom order based on this gallery design.",
            "",
            "Design: \(item.title)",
            "Gallery ID: \(item.id)",
        ]
        if let u = item.imageUrl, !u.isEmpty {
            lines.append("Reference photo: \(u)")
        }
        if let d = item.description, !d.isEmpty {
            lines.append("")
            lines.append("Notes from listing: \(d)")
        }
        lines.append("")
        lines.append("Please reply with pricing and next steps. (Event date, servings, or changes welcome below.)")
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
