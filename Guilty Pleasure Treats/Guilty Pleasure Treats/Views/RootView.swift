//
//  RootView.swift
//  Guilty Pleasure Treats
//
//  Shows splash then main tab (Home, Cart, Orders). Hidden 5-tap reveals Admin.
//

import SwiftUI
import Combine

struct RootView: View {
    @State private var showSplash = true
    @State private var showAdmin = false
    @ObservedObject private var tabRouter = TabRouter.shared
    @ObservedObject private var notificationService = NotificationService.shared

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
        #if os(iOS)
        .fullScreenCover(isPresented: $showAdmin) {
            AdminView()
        }
        #else
        .sheet(isPresented: $showAdmin) {
            AdminView()
                .frame(minWidth: 720, maxWidth: 880, minHeight: 600, maxHeight: 800)
        }
        #endif
        .onChange(of: notificationService.pendingPushAction) { _, new in
            guard let new else { return }
            switch new {
            case .openOrder:
                tabRouter.selectedTab = 4
                notificationService.clearPendingPushAction()
            case .openEvents:
                tabRouter.selectedTab = 0
                notificationService.clearPendingPushAction()
            default:
                showAdmin = true
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
    }
    
    private var mainTabView: some View {
        TabView(selection: $tabRouter.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            NavigationStack { MenuView() }
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Menu")
                }
                .tag(1)
            NavigationStack { CartView() }
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Cart")
                }
                .tag(2)
            NavigationStack { RewardsView() }
                .tabItem {
                    Image(systemName: "gift.fill")
                    Text("Rewards")
                }
                .tag(3)
            NavigationStack { OrdersView() }
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Orders")
                }
                .tag(4)
            NavigationStack { ProfileView() }
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Account")
                }
                .tag(5)
        }
        .tint(AppConstants.Colors.accent)
    }
}
