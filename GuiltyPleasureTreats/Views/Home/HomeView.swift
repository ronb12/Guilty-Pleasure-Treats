//
//  HomeView.swift
//  Guilty Pleasure Treats
//
//  Home: featured products, promotions banner, browse menu CTA.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showMenu = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    promotionsBanner
                    
                    customCakeCard
                    aiCakeDesignerCard
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if !viewModel.featuredProducts.isEmpty {
                        sectionHeader("Featured Treats")
                        featuredScroll
                    }
                    
                    browseMenuButton
                }
                .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                .padding(.bottom, 24)
            }
            .background(AppConstants.Colors.secondary)
            .navigationTitle("Guilty Pleasure Treats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: CartView()) {
                        Image(systemName: "cart.fill")
                            .foregroundStyle(AppConstants.Colors.accent)
                    }
                }
            }
            .navigationDestination(isPresented: $showMenu) {
                MenuView()
            }
            .task { await viewModel.loadFeatured() }
            .refreshable { await viewModel.loadFeatured() }
        }
    }
    
    private var customCakeCard: some View {
        NavigationLink(destination: CustomCakeBuilderView()) {
            HStack {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppConstants.Colors.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Build Your Custom Cake")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Text("Choose size, flavor, frosting & add a message")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var aiCakeDesignerCard: some View {
        NavigationLink(destination: AICakeDesignerView()) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 36))
                    .foregroundStyle(AppConstants.Colors.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Cake Designer")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Text("Describe your dream cake and we'll generate a preview")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var promotionsBanner: some View {
        HStack {
            Image(systemName: "tag.fill")
                .font(.title2)
                .foregroundStyle(AppConstants.Colors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sweet Deals")
                    .font(.headline)
                    .foregroundStyle(AppConstants.Colors.textPrimary)
                Text("Order 3+ items and get 10% off your next visit!")
                    .font(.caption)
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(AppConstants.Colors.promotionBanner)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }
    
    private var featuredScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.featuredProducts) { product in
                    NavigationLink(destination: ProductDetailView(product: product)) {
                        ProductCard(product: product)
                            .frame(width: 200)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, -AppConstants.Layout.screenHorizontalPadding)
    }
    
    private var browseMenuButton: some View {
        PrimaryButton(title: "Browse Menu") {
            showMenu = true
        }
    }
}
