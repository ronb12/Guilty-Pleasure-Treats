//
//  Guilty_Pleasure_TreatsApp.swift
//  Guilty Pleasure Treats
//
//  Created by Ronell J Bradley on 3/15/26.
//

import SwiftUI
import Combine

@main
struct Guilty_Pleasure_TreatsApp: App {
    #if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        #if !os(macOS)
        if let key = AppConstants.stripePublishableKey, !key.isEmpty {
            StripeService.configure(publishableKey: key)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppearanceWrapper {
                RootView()
            }
        }
        #if os(macOS)
        .commands {
            // Menu bar navigation so users can always return to Home (App Store / HIG expectation).
            CommandMenu("Navigate") {
                Button("Home") {
                    TabRouter.shared.selectedTab = 0
                }
                .keyboardShortcut("1", modifiers: .command)
                Button("Menu") {
                    TabRouter.shared.switchToMenu()
                }
                .keyboardShortcut("2", modifiers: .command)
                Button("Cart") {
                    TabRouter.shared.switchToCart()
                }
                .keyboardShortcut("3", modifiers: .command)
                Button("Rewards") {
                    TabRouter.shared.selectedTab = 3
                }
                .keyboardShortcut("4", modifiers: .command)
                Button("Orders") {
                    TabRouter.shared.selectedTab = 4
                }
                .keyboardShortcut("5", modifiers: .command)
                Button("Account") {
                    TabRouter.shared.selectedTab = 5
                }
                .keyboardShortcut("6", modifiers: .command)
            }
        }
        #endif
    }
}
