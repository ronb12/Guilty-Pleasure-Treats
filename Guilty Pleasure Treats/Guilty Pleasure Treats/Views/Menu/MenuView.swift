//
//  MenuView.swift
//  Guilty Pleasure Treats
//
//  Menu by category: Cupcakes, Cookies, Cakes, Brownies, Seasonal.
//

import SwiftUI

private enum MenuNavRoute: Hashable {
    case gallery
    case customCake
}

struct MenuView: View {
    @StateObject private var viewModel = MenuViewModel()
    @StateObject private var cart = CartManager.shared
    @ObservedObject private var favorites = FavoritesManager.shared
    @State private var showOnlyVegetarian = false
    @State private var searchText = ""
    /// nil = All categories; otherwise filter to this category.
    @State private var selectedCategoryFilter: String?
    /// When set, navigate to product detail (avoids NavigationLink tap issues in ScrollView).
    @State private var selectedProduct: Product?

    /// All products from all categories (for vegetarian section / filter).
    private var allProducts: [Product] {
        viewModel.productsByCategory.values.flatMap { $0 }
    }

    private var vegetarianProducts: [Product] {
        allProducts.filter(\.isVegetarian)
    }

    /// Fuzzy match: each word in the search query must appear (as substring) in name or category. Word order ignored.
    private var searchResults: [Product] {
        let raw = searchText.trimmingCharacters(in: .whitespaces)
        let query = raw.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard !query.isEmpty else { return [] }
        let base = showOnlyVegetarian ? vegetarianProducts : allProducts
        let categoryFiltered: [Product]
        if let cat = selectedCategoryFilter {
            categoryFiltered = base.filter { $0.category == cat }
        } else {
            categoryFiltered = base
        }
        return categoryFiltered.filter { product in
            let name = product.name.lowercased()
            let category = product.category.lowercased()
            return query.allSatisfy { word in
                name.contains(word) || category.contains(word)
            }
        }
    }

    /// Stable identity for chips (avoid `id: \.offset` reordering when categories load).
    private struct MenuCategoryChip: Identifiable, Equatable {
        var id: String { filter ?? "__all__" }
        let filter: String?
        let label: String
    }

    /// Chips should reflect admin category configuration, even if a category currently has no in-stock products.
    private var chipCategoryNames: [String] {
        if !viewModel.categoryOrder.isEmpty { return viewModel.categoryOrder }
        return viewModel.orderedCategoryNames
    }

    private var categoryChips: [MenuCategoryChip] {
        [MenuCategoryChip(filter: nil, label: "All")]
            + chipCategoryNames.map { MenuCategoryChip(filter: $0, label: $0) }
    }

    /// When a category chip is selected, show only that category; otherwise show all in normal order.
    private var displayCategoryNames: [String] {
        if let cat = selectedCategoryFilter {
            let products = viewModel.productsByCategory[cat] ?? []
            return products.isEmpty ? [] : [cat]
        }
        return viewModel.orderedCategoryNames
    }

    /// Apply category filter to a product list (for favorites base when chip is selected).
    private func categoryFilteredProducts(_ products: [Product]) -> [Product] {
        guard let cat = selectedCategoryFilter else { return products }
        return products.filter { $0.category == cat }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                Section {
                    menuScrollableBody
                        .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                } header: {
                    menuStickyHeader
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppConstants.Colors.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppConstants.Colors.secondary)
        .macOSConstrainedContent()
        .navigationTitle("Menu")
        .inlineNavigationTitle()
        .navigationDestination(for: MenuNavRoute.self) { route in
            switch route {
            case .gallery: CakeGalleryView()
            case .customCake: CustomCakeBuilderView()
            }
        }
        .navigationDestination(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
        .task { await viewModel.loadMenu() }
        .refreshable { await viewModel.loadMenu() }
    }

    /// Menu content below the pinned header (search + category chips).
    @ViewBuilder
    private var menuScrollableBody: some View {
        VStack(alignment: .leading, spacing: 24) {
            Toggle(isOn: $showOnlyVegetarian) {
                Label("Show only vegetarian", systemImage: "leaf.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            .tint(AppConstants.Colors.accent)
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))

            NavigationLink(value: MenuNavRoute.customCake) {
                HStack {
                    Image(systemName: "birthday.cake.fill")
                        .foregroundStyle(AppConstants.Colors.accent)
                    Text("Build a Custom Cake")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                .padding()
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            NavigationLink(value: MenuNavRoute.gallery) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(AppConstants.Colors.accent)
                    Text("Gallery")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                .padding()
                .background(AppConstants.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if !searchResults.isEmpty {
                categorySection(title: "Search results", products: searchResults, showFavoriteButton: true, onTapProduct: { selectedProduct = $0 })
            } else if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("No items match \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                let baseForFavorites = categoryFilteredProducts(showOnlyVegetarian ? vegetarianProducts : allProducts)
                let favoriteProducts = favorites.favoriteProducts(from: baseForFavorites)
                if !favoriteProducts.isEmpty {
                    categorySection(title: "Favorites", products: favoriteProducts, showFavoriteButton: true, onTapProduct: { selectedProduct = $0 })
                }
                if !showOnlyVegetarian, !vegetarianProducts.isEmpty, selectedCategoryFilter == nil {
                    categorySection(title: "Vegetarian", products: vegetarianProducts, showFavoriteButton: true, onTapProduct: { selectedProduct = $0 })
                }
                ForEach(displayCategoryNames, id: \.self) { categoryName in
                    if let products = viewModel.productsByCategory[categoryName] {
                        let filtered = showOnlyVegetarian ? products.filter(\.isVegetarian) : products
                        if !filtered.isEmpty {
                            categorySection(title: categoryName, products: filtered, showFavoriteButton: true, onTapProduct: { selectedProduct = $0 })
                        }
                    }
                }
            }
        }
    }

    /// Search bar + category chips; pinned under nav bar while menu scrolls (LazyVStack section header).
    private var menuStickyHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let msg = viewModel.errorMessage {
                ErrorMessageBanner(message: msg) {
                    viewModel.errorMessage = nil
                }
            }
            HStack(spacing: 8) {
                TextField("Search menu", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categoryChips) { chip in
                        let isSelected = selectedCategoryFilter == chip.filter
                        Button {
                            selectedCategoryFilter = chip.filter
                        } label: {
                            Text(chip.label)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .white : AppConstants.Colors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? AppConstants.Colors.accent : AppConstants.Colors.cardBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(chip.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .animation(nil, value: categoryChips.map(\.id))
        }
        .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppConstants.Colors.textSecondary.opacity(0.12))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }
    
    private func categorySection(title: String, products: [Product], showFavoriteButton: Bool = false, onTapProduct: ((Product) -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)

            VStack(spacing: 12) {
                ForEach(products) { product in
                    ProductCard(
                        product: product,
                        onTap: onTapProduct.map { handler in { handler(product) } },
                        onAddToCart: product.hasSizeOptions ? nil : { cart.add(product: product) },
                        isFavorite: showFavoriteButton ? favorites.isFavorite(productId: product.id) : false,
                        onToggleFavorite: showFavoriteButton ? { favorites.toggle(productId: product.id) } : nil
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
