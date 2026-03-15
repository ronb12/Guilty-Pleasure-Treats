//
//  SettingsView.swift
//  Guilty Pleasure Treats
//
//  App settings: notifications, legal, about, sign out.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @StateObject private var auth = AuthService.shared
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("settings.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    
    private var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }
    
    var body: some View {
        List {
            appearanceSection
            notificationsSection
            legalSection
            aboutSection
            if auth.currentUser != nil {
                signOutSection
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppConstants.Colors.secondary)
    }
    
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: Binding(
                get: { appearance },
                set: { appearance = $0 }
            )) {
                ForEach(AppAppearance.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(AppConstants.Colors.accent)
        }
    }
    
    private var notificationsSection: some View {
        Section {
            Toggle("Order updates & promotions", isOn: $notificationsEnabled)
                .tint(AppConstants.Colors.accent)
                .onChange(of: notificationsEnabled) { _, new in
                    if new {
                        NotificationService.shared.requestPermissionAndRegister()
                    }
                }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Receive push notifications for order status and special offers.")
        }
    }
    
    private var legalSection: some View {
        Section("Legal") {
            NavigationLink("Privacy Policy") {
                DocumentView(title: "Privacy Policy", markdown: LegalContent.privacyPolicyMarkdown)
            }
            NavigationLink("Terms of Service") {
                DocumentView(title: "Terms of Service", markdown: LegalContent.termsOfServiceMarkdown)
            }
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                HStack {
                    Text("Build")
                    Spacer()
                    Text(build)
                        .foregroundStyle(AppConstants.Colors.textSecondary)
                }
            }
            if let url = URL(string: AppConstants.supportURLString) {
                Link(destination: url) {
                    HStack {
                        Text("Support")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
                .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            if let url = URL(string: AppConstants.instagramURLString) {
                Link(destination: url) {
                    HStack {
                        Text("Instagram")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(AppConstants.Colors.textSecondary)
                    }
                }
                .foregroundStyle(AppConstants.Colors.textPrimary)
            }
            HStack {
                Text("Built by Ronell Bradley")
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
            HStack {
                Text("Product of Bradley, Virtual Solutions, LLC")
                    .foregroundStyle(AppConstants.Colors.textSecondary)
            }
        }
    }
    
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                try? auth.signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }
}
