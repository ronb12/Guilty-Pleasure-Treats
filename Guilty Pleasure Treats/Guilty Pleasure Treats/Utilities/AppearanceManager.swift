//
//  AppearanceManager.swift
//  Guilty Pleasure Treats
//
//  Persists and resolves Light / System / Dark appearance for the app.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case light = "light"
    case system = "system"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .system: return "System"
        case .dark: return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .system: return nil
        case .dark: return .dark
        }
    }
}

/// Wraps content and applies the user's preferred color scheme (Light / System / Dark).
struct AppearanceWrapper<Content: View>: View {
    @AppStorage("settings.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }
    
    var body: some View {
        content()
            .preferredColorScheme(appearance.colorScheme)
    }
}
