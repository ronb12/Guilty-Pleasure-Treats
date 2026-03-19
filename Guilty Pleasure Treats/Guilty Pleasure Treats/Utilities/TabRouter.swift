//
//  TabRouter.swift
//  Guilty Pleasure Treats
//
//  Shared tab selection so views can switch tabs (e.g. "View Cart" after add-to-cart, "Continue Shopping" from cart).
//

import SwiftUI
import Combine

final class TabRouter: ObservableObject {
    static let shared = TabRouter()

    /// 0 = Home, 1 = Menu, 2 = Cart, 3 = Rewards, 4 = Orders, 5 = Account
    @Published var selectedTab: Int = 0

    func switchToCart() { selectedTab = 2 }
    func switchToMenu() { selectedTab = 1 }
    func switchToHome() { selectedTab = 0 }

    private init() {}
}
