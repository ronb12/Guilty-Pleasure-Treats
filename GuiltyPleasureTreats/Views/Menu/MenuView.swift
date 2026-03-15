//
//  MenuView.swift
//  Guilty Pleasure Treats
//
//  Menu by category: Cupcakes, Cookies, Cakes, Brownies, Seasonal.
//

import SwiftUI

struct MenuView: View {
    @StateObject private var viewModel = MenuViewModel()
    @StateObject private var cart = CartManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let msg = viewModel.errorMessage {
                    ErrorMessageBanner(message: msg) {
                        viewModel.errorMessage = nil
                    }
                }
                
                NavigationLink(destination: CustomCakeBuilderView()) {
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
                NavigationLink(destination: AICakeDesignerView()) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(AppConstants.Colors.accent)
                        Text("AI Cake Designer")
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
                } else {
                    ForEach(ProductCategory.allCases) { category in
                        if let products = viewModel.productsByCategory[category.rawValue], !products.isEmpty {
                            categorySection(title: category.rawValue, products: products)
                        }
                    }
                }
            }
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.secondary)
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadMenu() }
        .refreshable { await viewModel.loadMenu() }
    }
    
    private func categorySection(title: String, products: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            
            LazyVStack(spacing: 12) {
                ForEach(products) { product in
                    NavigationLink(destination: ProductDetailView(product: product)) {
                        ProductCard(product: product) {
                            cart.add(product: product)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
