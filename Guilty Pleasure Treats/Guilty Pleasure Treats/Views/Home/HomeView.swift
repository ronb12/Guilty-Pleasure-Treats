//
//  HomeView.swift
//  Guilty Pleasure Treats
//
//  Home: hero, featured products, promotions, custom cake & AI designer, browse menu.
//

import SwiftUI

private enum HomeNavRoute: Hashable {
    case gallery
    case customCake
    case events
    case reviews
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var notificationService = NotificationService.shared
    @State private var showMenu = false
    @State private var showNotificationCenter = false
    @State private var heroVisible = false
    @State private var sectionVisible = false
    @State private var scrollToTop = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection
                            .id("top")
                        trustStrip
                        
                        VStack(alignment: .leading, spacing: 24) {
                            promotionsSection
                                .opacity(sectionVisible ? 1 : 0)
                                .offset(y: sectionVisible ? 0 : 12)
                            
                            quickActionsSection

                            middleMenuPrompt

                            reviewsSection
                            eventsSection
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                            } else if !viewModel.featuredProducts.isEmpty {
                                sectionHeader("Featured Treats")
                                    .opacity(sectionVisible ? 1 : 0)
                                    .offset(y: sectionVisible ? 0 : 8)
                                featuredScroll
                                    .opacity(sectionVisible ? 1 : 0)
                                    .offset(y: sectionVisible ? 0 : 12)
                            } else {
                                EmptyView()
                            }
                            
                            dividerAboveBrowse
                            
                            browseMenuButton
                                .opacity(sectionVisible ? 1 : 0)
                                .offset(y: sectionVisible ? 0 : 8)
                        }
                        .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
                .background(AppConstants.Colors.secondary)
                .onChange(of: scrollToTop) { _, value in
                    if value {
                        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top") }
                        scrollToTop = false
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        scrollToTop = true
                    } label: {
                        HStack(spacing: 10) {
                            Image("HomeLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Guilty Pleasure Treats")
                                .font(.custom("Snell Roundhand", size: 22))
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    HStack(spacing: 16) {
                        Button {
                            showNotificationCenter = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.body)
                                    .foregroundStyle(AppConstants.Colors.accent)
                                if notificationService.unreadInAppNotificationCount > 0 {
                                    Text("\(min(notificationService.unreadInAppNotificationCount, 99))")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Circle().fill(.red))
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        NavigationLink(destination: CartView()) {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(AppConstants.Colors.accent)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppConstants.Colors.cardBackground))
                }
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView()
            }
            .navigationDestination(isPresented: $showMenu) {
                MenuView()
            }
            .navigationDestination(for: HomeNavRoute.self) { route in
                switch route {
                case .gallery: CakeGalleryView()
                case .customCake: CustomCakeBuilderView()
                case .events: EventsView()
                case .reviews: ReviewsView()
                }
            }
            .task { await viewModel.loadFeatured() }
            .refreshable { await viewModel.loadFeatured() }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { heroVisible = true }
                withAnimation(.easeOut(duration: 0.5).delay(0.2)) { sectionVisible = true }
            }
            .macOSConstrainedContent()
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            Image("LandingLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 220)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1 : 0.92)
            
            Text("Fresh baked with love")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.accent)
                .opacity(heroVisible ? 1 : 0)
                .offset(y: heroVisible ? 0 : 6)
            
            Text("Handcrafted cupcakes, cookies, cakes & more. Pick up & delivery (w/ fee) — NYC & North NJ only; shipping available.")
                .font(.subheadline)
                .foregroundStyle(AppConstants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(heroVisible ? 1 : 0)
                .offset(y: heroVisible ? 0 : 8)
            
            Button {
                showMenu = true
            } label: {
                Text("See menu")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.Colors.accent)
            }
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [AppConstants.Colors.primary.opacity(0.6), AppConstants.Colors.secondary],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var trustStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Button { showMenu = true } label: {
                    Label("Fresh daily", systemImage: "leaf.fill")
                }
                .buttonStyle(.plain)
                NavigationLink(destination: CustomCakeBuilderView()) {
                    Label("Custom cakes", systemImage: "birthday.cake.fill")
                }
                .buttonStyle(.plain)
                Button { showMenu = true } label: {
                    Label("Pick up & delivery (NYC & North NJ)", systemImage: "car.fill")
                }
                .buttonStyle(.plain)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(AppConstants.Colors.textSecondary)
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppConstants.Colors.cardBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppConstants.Colors.accent.opacity(0.12))
                .frame(height: 1)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create something sweet")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            
            customCakeCard
            cakeGalleryCard
        }
        .opacity(sectionVisible ? 1 : 0)
        .offset(y: sectionVisible ? 0 : 12)
    }
    
    private var customCakeCard: some View {
        NavigationLink(value: HomeNavRoute.customCake) {
            HStack(spacing: 16) {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppConstants.Colors.accent)
                    .frame(width: 48, height: 48)
                    .background(AppConstants.Colors.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConstants.Colors.accent.opacity(0.8))
            }
            .padding(AppConstants.Layout.cardPadding)
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                    .stroke(AppConstants.Colors.accent.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
    
    private var middleMenuPrompt: some View {
        Text("Check out our full menu below for cupcakes, cookies, cakes, and more.")
            .font(.subheadline)
            .foregroundStyle(AppConstants.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .opacity(sectionVisible ? 1 : 0)
    }

    private var eventsSection: some View {
        Group {
            sectionHeaderWithSeeAll(title: "Events", seeAllRoute: .events)
                .opacity(sectionVisible ? 1 : 0)
                .offset(y: sectionVisible ? 0 : 8)
            if viewModel.upcomingEvents.isEmpty {
                NavigationLink(value: HomeNavRoute.events) {
                    Text("No upcoming events. Tap to see events.")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppConstants.Layout.cardPadding)
                        .background(AppConstants.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .opacity(sectionVisible ? 1 : 0)
                .offset(y: sectionVisible ? 0 : 8)
            } else {
                eventsPreview
                    .opacity(sectionVisible ? 1 : 0)
                    .offset(y: sectionVisible ? 0 : 12)
            }
        }
    }

    private var eventsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.upcomingEvents.prefix(3)) { event in
                NavigationLink(value: HomeNavRoute.events) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(AppConstants.Colors.accent)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                            if let start = event.startAt {
                                Text(start, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(AppConstants.Colors.textSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppConstants.Colors.accent.opacity(0.8))
                    }
                    .padding(AppConstants.Layout.cardPadding)
                    .background(AppConstants.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                }
                .buttonStyle(.plain)
            }
            if viewModel.upcomingEvents.count > 3 {
                NavigationLink(value: HomeNavRoute.events) {
                    Text("See all events")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
        }
    }

    private var reviewsSection: some View {
        Group {
            sectionHeaderWithSeeAll(title: "Reviews", seeAllRoute: .reviews)
                .opacity(sectionVisible ? 1 : 0)
                .offset(y: sectionVisible ? 0 : 8)
            if viewModel.reviews.isEmpty {
                NavigationLink(value: HomeNavRoute.reviews) {
                    Text("No reviews yet. Tap to see reviews.")
                        .font(.subheadline)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppConstants.Layout.cardPadding)
                        .background(AppConstants.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .opacity(sectionVisible ? 1 : 0)
                .offset(y: sectionVisible ? 0 : 8)
            } else {
                reviewsPreview
                    .opacity(sectionVisible ? 1 : 0)
                    .offset(y: sectionVisible ? 0 : 12)
            }
        }
    }

    private var reviewsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.reviews.prefix(3)) { review in
                NavigationLink(value: HomeNavRoute.reviews) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let rating = review.rating, rating > 0 {
                            HStack(spacing: 2) {
                                ForEach(0..<min(rating, 5), id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(AppConstants.Colors.accent)
                                }
                            }
                        }
                        if let text = review.text, !text.isEmpty {
                            Text(text)
                                .font(.subheadline)
                                .foregroundStyle(AppConstants.Colors.textPrimary)
                                .lineLimit(2)
                        }
                        if let name = review.authorName, !name.isEmpty {
                            Text("— \(name)")
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppConstants.Layout.cardPadding)
                    .background(AppConstants.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
                }
                .buttonStyle(.plain)
            }
            if viewModel.reviews.count > 3 {
                NavigationLink(value: HomeNavRoute.reviews) {
                    Text("See all reviews")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppConstants.Colors.accent)
                }
            }
        }
    }

    private var cakeGalleryCard: some View {
        NavigationLink(value: HomeNavRoute.gallery) {
            HStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 32))
                    .foregroundStyle(AppConstants.Colors.accent)
                    .frame(width: 48, height: 48)
                    .background(AppConstants.Colors.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gallery")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Text("Browse our photos and order something like yours")
                        .font(.caption)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConstants.Colors.accent.opacity(0.8))
            }
            .padding(AppConstants.Layout.cardPadding)
            .background(AppConstants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                    .stroke(AppConstants.Colors.accent.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
    
    /// Live promos from admin (`GET /api/promotions`); hidden when none are active in-date.
    @ViewBuilder
    private var promotionsSection: some View {
        if viewModel.activePromotions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "tag.fill")
                        .font(.title2)
                        .foregroundStyle(AppConstants.Colors.accent)
                    Text("Sweet deals")
                        .font(.headline)
                        .foregroundStyle(AppConstants.Colors.textPrimary)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.activePromotions, id: \.listingId) { promo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(promo.customerFacingOfferLine)
                                .font(.caption)
                                .foregroundStyle(AppConstants.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                            if let cap = promo.homeValidityCaption {
                                Text(cap)
                                    .font(.caption2)
                                    .foregroundStyle(AppConstants.Colors.textSecondary.opacity(0.9))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(AppConstants.Layout.cardPadding)
            .background(AppConstants.Colors.promotionBanner)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.Layout.cardCornerRadius)
                    .stroke(AppConstants.Colors.accent.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(AppConstants.Colors.textPrimary)
    }

    private func sectionHeaderWithSeeAll(title: String, seeAllRoute: HomeNavRoute) -> some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppConstants.Colors.textPrimary)
            Spacer()
            NavigationLink(value: seeAllRoute) {
                Text("See all")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppConstants.Colors.accent)
            }
        }
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
            .padding(.horizontal, AppConstants.Layout.screenHorizontalPadding)
        }
        .padding(.horizontal, -AppConstants.Layout.screenHorizontalPadding)
    }
    
    private var dividerAboveBrowse: some View {
        Rectangle()
            .fill(AppConstants.Colors.accent.opacity(0.12))
            .frame(height: 1)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
    
    private var browseMenuButton: some View {
        Button {
            showMenu = true
        } label: {
            HStack(spacing: 6) {
                Text("Browse full menu")
                    .fontWeight(.semibold)
                Text("→")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppConstants.Colors.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.Layout.buttonCornerRadius))
            .shadow(color: AppConstants.Colors.accent.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
