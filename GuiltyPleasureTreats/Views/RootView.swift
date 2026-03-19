//
//  RootView.swift
//  Guilty Pleasure Treats
//
//  Shows SplashView on launch, then main tab interface (Home, Menu, Cart, Rewards, More).
//

import SwiftUI

struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else {
                mainTabView
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
    }

    private var mainTabView: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            MenuView()
                .tabItem {
                    Label("Menu", systemImage: "list.bullet")
                }
                .tag(1)
            CartView()
                .tabItem {
                    Label("Cart", systemImage: "cart.fill")
                }
                .tag(2)
            RewardsView()
                .tabItem {
                    Label("Rewards", systemImage: "gift.fill")
                }
                .tag(3)
            ProfileView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(4)
        }
        .tint(Color("AppAccent"))
    }
}

#Preview {
    RootView()
}
