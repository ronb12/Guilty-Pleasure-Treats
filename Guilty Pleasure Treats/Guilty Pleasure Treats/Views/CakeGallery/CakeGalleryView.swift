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
            GalleryDetailSheet(item: item) {
                Task {
                    await viewModel.orderItem(item)
                    selectedItem = nil
                }
            }
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
    var onOrder: () -> Void
    @Environment(\.dismiss) private var dismiss

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
                        }
                    }
                    PrimaryButton(title: "Order this", action: {
                        onOrder()
                        dismiss()
                    })
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
        }
    }
}
