//
//  ProductDetailView.swift
//  Guilty Pleasure Treats
//
//  Product detail: image, description, price, quantity, special instructions, Add to Cart.
//

import SwiftUI

struct ProductDetailView: View {
    /// Initial product from menu/list; refreshed from API when view appears so owner changes (name, price, image) are shown.
    @State private var product: Product
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cart = CartManager.shared
    @ObservedObject private var tabRouter = TabRouter.shared
    @State private var quantity = 1
    @State private var specialInstructions = ""
    @State private var addedToCart = false
    /// When `product.sizeOptions` is set, must match one option id (default: first).
    @State private var selectedSizeId: String = ""
    
    init(product: Product) {
        _product = State(initialValue: product)
    }
    
    /// Refetch product by id when view appears so customer sees latest name, price, image after owner edits.
    private var canRefetchProduct: Bool {
        guard let id = product.id else { return false }
        return !id.hasPrefix("sample-") && !id.hasPrefix("custom-") && !id.hasPrefix("aicake-")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Image only – fixed height, no text overlay
                ProductImageView(urlString: product.imageURL, placeholderName: "photo")
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .accessibilityLabel("\(product.name) product image")
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: AppConstants.Layout.cardCornerRadius,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: AppConstants.Layout.cardCornerRadius
                        )
                    )

                // 2. Product info (name, description, price) under the image, then quantity & Add to Cart
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text(product.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppConstants.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        if product.isVegetarian {
                            Label("Vegetarian", systemImage: "leaf.fill")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                    }

                    Text(product.productDescription)
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(product.unitPrice(forSizeId: selectedSizeId.isEmpty ? nil : selectedSizeId).currencyFormatted)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConstants.Colors.accent)

                    if product.hasSizeOptions, let opts = product.sizeOptions {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Size")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            Picker("Size", selection: $selectedSizeId) {
                                ForEach(opts) { o in
                                    Text("\(o.label) — \(o.price.currencyFormatted)").tag(o.id)
                                }
                            }
                            // Same menu style on iOS and macOS (shared target sources).
                            .pickerStyle(.menu)
                        }
                    }

                    if product.isUnavailableOnMenu {
                        Text("Currently sold out")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    } else {
                        quantitySelector
                        specialInstructionsField
                        addToCartButton
                    }
                }
                .padding(AppConstants.Layout.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppConstants.Colors.cardBackground)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: AppConstants.Layout.cardCornerRadius,
                        bottomTrailingRadius: AppConstants.Layout.cardCornerRadius,
                        topTrailingRadius: 0
                    )
                )
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle(product.name)
        .inlineNavigationTitle()
        .task {
            guard canRefetchProduct, let id = product.id else {
                applyDefaultSelectedSize()
                return
            }
            if let updated = try? await VercelService.shared.fetchProduct(id: id) {
                product = updated
            }
            applyDefaultSelectedSize()
        }
        .onChange(of: product.id) { _, _ in
            applyDefaultSelectedSize()
        }
        .alert("Added to Cart", isPresented: $addedToCart) {
            Button("Continue Shopping") {
                dismiss()
            }
            Button("View Cart") {
                tabRouter.switchToCart()
                dismiss()
            }
        } message: {
            let sizeNote = product.sizeLabel(forSizeId: selectedSizeId.isEmpty ? nil : selectedSizeId).map { " (\($0))" } ?? ""
            Text("\(quantity) x \(product.name)\(sizeNote) added to your cart.")
        }
    }

    private func applyDefaultSelectedSize() {
        guard let opts = product.sizeOptions, !opts.isEmpty else {
            selectedSizeId = ""
            return
        }
        if selectedSizeId.isEmpty || !opts.contains(where: { $0.id == selectedSizeId }) {
            selectedSizeId = opts[0].id
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
            let sid = product.hasSizeOptions ? (selectedSizeId.isEmpty ? product.sizeOptions?.first?.id : selectedSizeId) : nil
            let lbl = product.sizeLabel(forSizeId: sid)
            for _ in 0..<quantity {
                cart.add(
                    product: product,
                    quantity: 1,
                    specialInstructions: specialInstructions,
                    selectedSizeId: sid,
                    selectedSizeLabel: lbl
                )
            }
            addedToCart = true
        }
        .accessibilityHint("Adds \(product.name) to your cart")
    }
}
