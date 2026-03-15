//
//  RootView.swift
//  Guilty Pleasure Treats
//
//  Shows splash then main tab (Home, Cart, Orders). Hidden 5-tap reveals Admin.
//

import SwiftUI

struct RootView: View {
    @State private var showSplash = true
    @State private var showAdmin = false
    
    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .onTapGesture(count: 5) {
                        showAdmin = true
                    }
            } else {
                mainTabView
            }
        }
        .fullScreenCover(isPresented: $showAdmin) {
            AdminView()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            NavigationStack { CartView() }
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Cart")
                }
            NavigationStack { RewardsView() }
                .tabItem {
                    Image(systemName: "gift.fill")
                    Text("Rewards")
                }
            NavigationStack { OrdersView() }
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Orders")
                }
            NavigationStack { ProfileView() }
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Account")
                }
        }
        .tint(AppConstants.Colors.accent)
    }
}
